import SwiftUI
import SceneKit
import simd

struct PainBody3DView: View {
    let region: PainRegion
    @Binding var marks: [PainMark]
    var editable = true
    @State private var marking = false
    @State private var kind = PainMarkKind.point
    @State private var reset = 0
    @State private var turn = 0
    @State private var failure: String?
    var body: some View {
        VStack(spacing: 12) {
            if editable {
                Picker("操作方式", selection: $marking) {
                    Text("转一转").tag(false)
                    Text("点出疼处").tag(true)
                }.pickerStyle(.segmented)
                if marking {
                    Picker("标记形状", selection: $kind) {
                        ForEach(PainMarkKind.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }
            }
            PainScene(region: region, marking: marking && editable, kind: kind, reset: reset, turn: turn, marks: $marks, failure: $failure)
                .frame(height: 390)
                .clipShape(.rect(cornerRadius: 28))
                .accessibilityLabel("\(region.rawValue)三维人体；转动模式拖动旋转，标记模式点选表面")
            if let failure { Text(failure).font(.footnote).foregroundStyle(CX.coral) }
            HStack {
                Text(marking && editable ? (kind == .point ? "点一下身体表面" : kind == .area ? "沿疼痛范围画一圈" : "顺着疼痛走向划线") : "拖动旋转 · 双指缩放")
                    .font(.caption).foregroundStyle(CX.muted)
                Spacer()
                Button("回正") { reset += 1 }.frame(minHeight: 44)
            }
            HStack {
                Button { turn -= 1 } label: { Label("向左转", systemImage: "arrow.turn.up.left") }
                Spacer()
                Button { turn += 1 } label: { Label("向右转", systemImage: "arrow.turn.up.right") }
            }.frame(minHeight: 44)
            if editable {
                Button("撤销上一处三维标记") {
                    if let i = marks.lastIndex(where: \.hasSurfaceLocation) { marks.remove(at: i) }
                }.disabled(!marks.contains(where: \.hasSurfaceLocation)).frame(minHeight: 44)
            }
            Text("身体表面示意，不表示疼痛来自哪块肌肉、骨骼或器官。")
                .font(.caption).foregroundStyle(CX.muted)
        }
    }
}

private struct PainScene: UIViewRepresentable {
    let region: PainRegion
    let marking: Bool
    let kind: PainMarkKind
    let reset: Int
    let turn: Int
    @Binding var marks: [PainMark]
    @Binding var failure: String?
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.94, green: 0.97, blue: 0.99, alpha: 1)
        view.antialiasingMode = .multisampling4X
        context.coordinator.build(view)
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        c.parent = self
        if c.lastReset != reset || c.lastRegion != region { c.frameRegion(animated: !UIAccessibility.isReduceMotionEnabled); c.lastReset = reset }
        if c.lastTurn != turn {
            SCNTransaction.begin(); SCNTransaction.animationDuration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.3
            c.pivot.eulerAngles.y += Float(turn - c.lastTurn) * .pi / 4
            SCNTransaction.commit()
            c.lastTurn = turn
        }
        c.refreshMarkers()
    }

    final class Coordinator: NSObject {
        var parent: PainScene
        weak var view: SCNView?
        let pivot = SCNNode()
        let body = SCNNode()
        let camera = SCNNode()
        let markerRoot = SCNNode()
        let drawingRoot = SCNNode()
        var lastReset = 0
        var lastTurn = 0
        var lastRegion: PainRegion?
        var markerIDs: [UUID] = []
        var drawingPoints: [PainSurfacePoint] = []
        init(_ parent: PainScene) { self.parent = parent }

        struct Mesh: Decodable { let vertices: [[Float]]; let normals: [[Float]]; let indices: [Int32] }
        func build(_ view: SCNView) {
            self.view = view
            do {
                guard let url = Bundle.main.url(forResource: "pain-body-v1", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
                let mesh = try JSONDecoder().decode(Mesh.self, from: Data(contentsOf: url))
                guard !mesh.vertices.isEmpty, !mesh.indices.isEmpty, mesh.indices.count.isMultiple(of: 3),
                      mesh.vertices.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }), mesh.normals.count == mesh.vertices.count,
                      mesh.normals.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
                      mesh.indices.allSatisfy({ $0 >= 0 && Int($0) < mesh.vertices.count }) else { throw CocoaError(.fileReadCorruptFile) }
                let vertices = SCNGeometrySource(vertices: mesh.vertices.map { SCNVector3($0[0], $0[1], $0[2]) })
                let normals = SCNGeometrySource(normals: mesh.normals.map { SCNVector3($0[0], $0[1], $0[2]) })
                let faces = SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)
                body.geometry = SCNGeometry(sources: [vertices, normals], elements: [faces])
                let material = SCNMaterial()
                material.diffuse.contents = UIColor(red: 0.88, green: 0.91, blue: 0.94, alpha: 1)
                material.lightingModel = .physicallyBased
                material.roughness.contents = 0.56
                material.metalness.contents = 0.08
                body.geometry?.materials = [material]
                body.name = "body-surface"
                body.addChildNode(markerRoot)
                body.addChildNode(drawingRoot)
                pivot.addChildNode(body)
                let scene = SCNScene()
                scene.rootNode.addChildNode(pivot)
                camera.camera = SCNCamera()
                camera.camera?.zNear = 0.01
                camera.camera?.zFar = 30
                camera.camera?.fieldOfView = 38
                scene.rootNode.addChildNode(camera)
                for (position, intensity, color) in [(SCNVector3(-2, 3, 4), 1100.0, UIColor.white), (SCNVector3(2, 2, -3), 800.0, UIColor(red: 0.64, green: 0.79, blue: 1, alpha: 1))] {
                    let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni
                    light.light?.intensity = intensity; light.light?.color = color; light.position = position
                    scene.rootNode.addChildNode(light)
                }
                let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 350
                scene.rootNode.addChildNode(ambient)
                view.scene = scene; view.pointOfView = camera
                view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(rotate(_:))))
                view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:))))
                view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mark(_:))))
                // Begin with the whole body, then move closer to the selected region.
                lastRegion = parent.region
                body.position = SCNVector3(0, -1, 0)
                camera.position = SCNVector3(0, 0, 3.6)
                DispatchQueue.main.async { [weak self] in
                    self?.frameRegion(animated: !UIAccessibility.isReduceMotionEnabled)
                }
            } catch {
                DispatchQueue.main.async { self.parent.failure = "三维模型暂时无法载入，可以切回插画标记。" }
            }
        }
        func frameRegion(animated: Bool) {
            lastRegion = parent.region
            let focus: Float
            let distance: Float
            switch parent.region {
            case .head: focus = 1.83; distance = 0.85
            case .neck: focus = 1.60; distance = 1.2
            case .torso, .back: focus = 1.30; distance = 1.85
            case .arms: focus = 1.27; distance = 2.7
            case .legs: focus = 0.55; distance = 2.0
            }
            SCNTransaction.begin(); SCNTransaction.animationDuration = animated ? 0.45 : 0
            body.position = SCNVector3(0, -focus, 0)
            camera.position = SCNVector3(0, 0, distance)
            pivot.eulerAngles = SCNVector3(0, parent.region == .back ? Float.pi : 0, 0)
            SCNTransaction.commit()
        }
        @objc func rotate(_ gesture: UIPanGestureRecognizer) {
            guard let view else { return }
            if parent.marking {
                drawSurface(gesture, in: view)
                return
            }
            let delta = gesture.translation(in: view)
            pivot.eulerAngles.y += Float(delta.x) * 0.008
            pivot.eulerAngles.x = min(1.1, max(-1.1, pivot.eulerAngles.x + Float(delta.y) * 0.006))
            gesture.setTranslation(.zero, in: view)
        }
        @objc func zoom(_ gesture: UIPinchGestureRecognizer) {
            camera.position.z = min(4, max(0.5, camera.position.z / Float(gesture.scale)))
            gesture.scale = 1
        }
        @objc func mark(_ gesture: UITapGestureRecognizer) {
            guard parent.marking, parent.kind == .point, let view, let point = surfaceHit(at: gesture.location(in: view), in: view) else { return }
            // Persist mesh-local position, never the screen position.
            parent.marks.append(PainMark(angle: .front, kind: .point, points: [], name: "三维表面自选位置", surfacePoint: point))
        }
        private func drawSurface(_ gesture: UIPanGestureRecognizer, in view: SCNView) {
            guard parent.kind != .point else { return }
            if gesture.state == .began {
                drawingPoints.removeAll(keepingCapacity: true)
                drawingRoot.childNodes.forEach { $0.removeFromParentNode() }
            }
            if let point = surfaceHit(at: gesture.location(in: view), in: view), drawingPoints.count < 180 {
                let gap = drawingPoints.last.map { distance($0, point) }
                let shouldAppend = gap.map { $0 > 0.006 && $0 < 0.12 } ?? true
                if shouldAppend {
                    if let previous = drawingPoints.last { drawingRoot.addChildNode(segment(from: previous, to: point)) }
                    else { drawingRoot.addChildNode(dot(at: point, radius: 0.009)) }
                    drawingPoints.append(point)
                }
            }
            if gesture.state == .ended || gesture.state == .cancelled {
                let required = parent.kind == .area ? 6 : 2
                if drawingPoints.count >= required {
                    parent.marks.append(PainMark(angle: .front, kind: parent.kind, points: [], name: parent.kind == .area ? "三维表面圈选范围" : "三维表面疼痛走向", surfacePoint: nil, surfacePoints: drawingPoints))
                }
                drawingPoints = []
                drawingRoot.childNodes.forEach { $0.removeFromParentNode() }
            }
        }
        private func surfaceHit(at location: CGPoint, in view: SCNView) -> PainSurfacePoint? {
            guard let hit = view.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.all.rawValue]).first(where: { $0.node === body }) else { return nil }
            let p = hit.localCoordinates, n = hit.localNormal
            return PainSurfacePoint(x: p.x, y: p.y, z: p.z, nx: n.x, ny: n.y, nz: n.z)
        }
        private func distance(_ a: PainSurfacePoint, _ b: PainSurfacePoint) -> Float {
            simd_distance(SIMD3(a.x, a.y, a.z), SIMD3(b.x, b.y, b.z))
        }
        func refreshMarkers() {
            let marks = parent.marks.filter { $0.allSurfacePoints.first?.meshVersion == 1 }
            guard marks.map(\.id) != markerIDs else { return }
            markerIDs = marks.map(\.id)
            markerRoot.childNodes.forEach { $0.removeFromParentNode() }
            for mark in marks {
                let points = mark.allSurfacePoints
                guard !points.isEmpty else { continue }
                if mark.kind == .point { markerRoot.addChildNode(dot(at: points[0], radius: 0.014)) }
                else {
                    let sampled = sample(points, maximum: 72)
                    for pair in zip(sampled, sampled.dropFirst()) { markerRoot.addChildNode(segment(from: pair.0, to: pair.1)) }
                    if mark.kind == .area, let first = sampled.first, let last = sampled.last {
                        markerRoot.addChildNode(segment(from: last, to: first))
                        if sampled.count >= 3 { markerRoot.addChildNode(areaFill(sampled)) }
                    }
                }
            }
        }
        private func raised(_ p: PainSurfacePoint, amount: Float = 0.004) -> SIMD3<Float> {
            let normal = SIMD3(p.nx ?? 0, p.ny ?? 0, p.nz ?? 0)
            return SIMD3(p.x, p.y, p.z) + normal * amount
        }
        private func dot(at point: PainSurfacePoint, radius: CGFloat) -> SCNNode {
            let sphere = SCNSphere(radius: radius)
            sphere.firstMaterial?.diffuse.contents = UIColor(red: 0.82, green: 0.25, blue: 0.22, alpha: 1)
            let node = SCNNode(geometry: sphere); node.simdPosition = raised(point)
            return node
        }
        private func segment(from a: PainSurfacePoint, to b: PainSurfacePoint) -> SCNNode {
            let start = raised(a), end = raised(b), delta = end - start
            let cylinder = SCNCylinder(radius: 0.006, height: CGFloat(simd_length(delta)))
            cylinder.firstMaterial?.diffuse.contents = UIColor(red: 0.82, green: 0.25, blue: 0.22, alpha: 1)
            let node = SCNNode(geometry: cylinder)
            node.simdPosition = (start + end) / 2
            if simd_length(delta) > 0.0001 { node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta)) }
            return node
        }
        private func areaFill(_ points: [PainSurfacePoint]) -> SCNNode {
            let edge = points.map { raised($0, amount: 0.003) }
            let center = edge.reduce(SIMD3<Float>(repeating: 0), +) / Float(edge.count)
            let vertices = [center] + edge
            var indices: [Int32] = []
            for i in 1...edge.count { indices += [0, Int32(i), Int32(i == edge.count ? 1 : i + 1)] }
            let source = SCNGeometrySource(vertices: vertices.map { SCNVector3($0.x, $0.y, $0.z) })
            let geometry = SCNGeometry(sources: [source], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
            let material = SCNMaterial(); material.diffuse.contents = UIColor(red: 0.82, green: 0.25, blue: 0.22, alpha: 0.16); material.isDoubleSided = true
            geometry.materials = [material]
            return SCNNode(geometry: geometry)
        }
        private func sample(_ points: [PainSurfacePoint], maximum: Int) -> [PainSurfacePoint] {
            guard points.count > maximum else { return points }
            let stride = Double(points.count - 1) / Double(maximum - 1)
            return (0..<maximum).map { points[Int((Double($0) * stride).rounded())] }
        }
    }
}
