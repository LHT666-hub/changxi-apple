import SwiftUI
import SceneKit
import simd

struct PainBody3DView: View {
    let region: PainRegion
    @Binding var marks: [PainMark]
    var editable = true
    @State private var marking = false
    @State private var kind = PainMarkKind.point
    @State private var layer = PainAnatomyLayer.surface
    @State private var reset = 0
    @State private var turn = 0
    @State private var failure: String?
    var body: some View {
        VStack(spacing: 12) {
            Picker("解剖层", selection: $layer) {
                ForEach(PainAnatomyLayer.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: layer) { _, newValue in
                if newValue != .surface { marking = false }
            }
            if editable {
                Picker("操作方式", selection: $marking) {
                    Text("转一转").tag(false)
                    Text("点出疼处").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(layer != .surface)
                if marking {
                    Picker("标记形状", selection: $kind) {
                        ForEach(PainMarkKind.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                }
            }
            PainScene(region: region, layer: layer, marking: marking && editable, kind: kind, reset: reset, turn: turn, marks: $marks, failure: $failure)
                .frame(height: 390)
                .clipShape(.rect(cornerRadius: 28))
                .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(Color.white.opacity(0.72), lineWidth: 1) }
                .accessibilityLabel("\(region.rawValue)局部三维模型；转动模式拖动旋转，标记模式点选表面")
                .accessibilityIdentifier("pain-anatomy-model")
            if let failure { Text(failure).font(.footnote).foregroundStyle(CX.coral) }
            HStack {
                Text(marking && editable ? kind.instruction : "拖动旋转 · 双指缩放")
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
            Text(layer == .surface
                 ? "在\(region.rawValue)体表标记位置；位置记录不等于判断痛源。"
                 : "\(layer.rawValue)层用于帮助描述位置，标记请切回体表。")
                .font(.caption).foregroundStyle(CX.muted)
            Link("BodyParts3D 模型来源与许可", destination: URL(string: "https://dbarchive.biosciencedbc.jp/en/bodyparts3d/lic.html")!)
                .font(.caption2)
                .foregroundStyle(CX.muted)
        }
    }
}

private struct PainScene: UIViewRepresentable {
    let region: PainRegion
    let layer: PainAnatomyLayer
    let marking: Bool
    let kind: PainMarkKind
    let reset: Int
    let turn: Int
    @Binding var marks: [PainMark]
    @Binding var failure: String?
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.89, green: 0.94, blue: 0.97, alpha: 1)
        view.antialiasingMode = .multisampling4X
        context.coordinator.build(view)
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        c.parent = self
        if c.lastRegion != region { c.reloadAnatomy(for: region); c.frameRegion(animated: false) }
        if c.lastLayer != layer {
            c.applyLayer(layer)
            c.lastLayer = layer
        }
        if c.lastReset != reset { c.frameRegion(animated: !UIAccessibility.isReduceMotionEnabled); c.lastReset = reset }
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
        let anatomyRoot = SCNNode()
        let camera = SCNNode()
        let markerRoot = SCNNode()
        let drawingRoot = SCNNode()
        var lastReset = 0
        var lastTurn = 0
        var lastRegion: PainRegion?
        var lastLayer: PainAnatomyLayer?
        var markerIDs: [UUID] = []
        var drawingPoints: [PainSurfacePoint] = []
        var mesh: Mesh?
        var usesAnatomyAsset = false
        init(_ parent: PainScene) { self.parent = parent }

        struct Mesh: Decodable { let vertices: [[Float]]; let normals: [[Float]]; let indices: [Int32] }
        func build(_ view: SCNView) {
            self.view = view
            do {
                try loadFallbackMesh()
                body.addChildNode(anatomyRoot)
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
                for (position, intensity, color) in [(SCNVector3(-2, 3, 4), 260.0, UIColor.white), (SCNVector3(2, 2, -3), 150.0, UIColor(red: 0.58, green: 0.76, blue: 0.94, alpha: 1))] {
                    let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni
                    light.light?.intensity = intensity; light.light?.color = color; light.position = position
                    scene.rootNode.addChildNode(light)
                }
                let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 55
                scene.rootNode.addChildNode(ambient)
                view.scene = scene; view.pointOfView = camera
                view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(rotate(_:))))
                view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:))))
                view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mark(_:))))
                reloadAnatomy(for: parent.region)
                applyLayer(parent.layer)
                lastLayer = parent.layer
                DispatchQueue.main.async { [weak self] in
                    self?.frameRegion(animated: !UIAccessibility.isReduceMotionEnabled)
                }
            } catch {
                DispatchQueue.main.async { self.parent.failure = "三维模型暂时无法载入，可以切回插画标记。" }
            }
        }
        private func loadFallbackMesh() throws {
            guard let url = Bundle.main.url(forResource: "pain-body-v1", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            let mesh = try JSONDecoder().decode(Mesh.self, from: Data(contentsOf: url))
            guard !mesh.vertices.isEmpty, !mesh.indices.isEmpty, mesh.indices.count.isMultiple(of: 3),
                  mesh.vertices.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }), mesh.normals.count == mesh.vertices.count,
                  mesh.normals.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
                  mesh.indices.allSatisfy({ $0 >= 0 && Int($0) < mesh.vertices.count }) else { throw CocoaError(.fileReadCorruptFile) }
            self.mesh = mesh
        }
        func reloadAnatomy(for region: PainRegion) {
            body.geometry = nil
            anatomyRoot.childNodes.forEach { $0.removeFromParentNode() }
            anatomyRoot.eulerAngles = SCNVector3Zero
            usesAnatomyAsset = false
            if let url = Bundle.main.url(forResource: region.anatomyAssetName, withExtension: "usdc"),
               let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) {
                scene.rootNode.childNodes.forEach { anatomyRoot.addChildNode($0.clone()) }
                // Blender/USD assets are Z-up; SceneKit renders Y-up.
                anatomyRoot.eulerAngles.x = -.pi / 2
                usesAnatomyAsset = true
                styleAnatomyGeometry()
            } else {
                applyRegion(region)
            }
            lastRegion = region
            markerIDs = []
            applyLayer(parent.layer)
        }
        func applyLayer(_ layer: PainAnatomyLayer) {
            guard usesAnatomyAsset else { return }
            body.enumerateChildNodes { node, _ in
                guard let name = node.name else { return }
                guard let nodeLayer = PainAnatomyLayer.allCases.first(where: { name.hasPrefix($0.nodePrefix) }) else { return }
                let isContextShell = nodeLayer == .surface && layer != .surface
                node.isHidden = nodeLayer != layer && !isContextShell
                // A quiet outer silhouette keeps deeper anatomy spatially
                // understandable without covering the muscle or bone detail.
                node.opacity = isContextShell ? 0.12 : 1
            }
        }
        private func styleAnatomyGeometry() {
            body.enumerateChildNodes { [weak self] node, _ in
                guard let self, let layer = self.anatomyLayer(containing: node), let geometry = node.geometry else { return }
                let material = SCNMaterial()
                material.diffuse.contents = switch layer {
                case .surface: UIColor(red: 0.40, green: 0.58, blue: 0.66, alpha: 1)
                case .muscle: UIColor(red: 0.66, green: 0.27, blue: 0.23, alpha: 1)
                case .skeleton: UIColor(red: 0.82, green: 0.77, blue: 0.64, alpha: 1)
                }
                material.specular.contents = UIColor(white: 0.16, alpha: 1)
                material.roughness.contents = 0.82
                material.metalness.contents = 0
                material.lightingModel = .physicallyBased
                material.isDoubleSided = true
                geometry.materials = [material]
            }
        }
        private func anatomyLayer(containing node: SCNNode) -> PainAnatomyLayer? {
            var candidate: SCNNode? = node
            while let current = candidate, current !== body {
                if let name = current.name,
                   let layer = PainAnatomyLayer.allCases.first(where: { name.hasPrefix($0.nodePrefix) }) {
                    return layer
                }
                candidate = current.parent
            }
            return nil
        }
        func applyRegion(_ region: PainRegion) {
            guard let mesh else { return }
            var selected: [Int32] = []
            selected.reserveCapacity(mesh.indices.count / 3)
            for offset in stride(from: 0, to: mesh.indices.count, by: 3) {
                let triangle = [mesh.indices[offset], mesh.indices[offset + 1], mesh.indices[offset + 2]]
                let points = triangle.map { mesh.vertices[Int($0)] }
                let center = SIMD3<Float>(
                    points.map { $0[0] }.reduce(0, +) / 3,
                    points.map { $0[1] }.reduce(0, +) / 3,
                    points.map { $0[2] }.reduce(0, +) / 3
                )
                if includes(center, in: region) { selected.append(contentsOf: triangle) }
            }
            let used = Array(Set(selected)).sorted()
            let remap = Dictionary(uniqueKeysWithValues: used.enumerated().map { ($0.element, Int32($0.offset)) })
            let vertices = used.map { mesh.vertices[Int($0)] }
            let normals = used.map { mesh.normals[Int($0)] }
            let faces = selected.compactMap { remap[$0] }
            let vertexSource = SCNGeometrySource(vertices: vertices.map { SCNVector3($0[0], $0[1], $0[2]) })
            let normalSource = SCNGeometrySource(normals: normals.map { SCNVector3($0[0], $0[1], $0[2]) })
            body.geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [SCNGeometryElement(indices: faces, primitiveType: .triangles)])
            body.name = "surface__fallback"
            let material = SCNMaterial()
            material.diffuse.contents = UIColor(red: 0.53, green: 0.65, blue: 0.74, alpha: 1)
            material.specular.contents = UIColor(white: 0.88, alpha: 1)
            material.lightingModel = .blinn
            material.shininess = 0.18
            material.isDoubleSided = true
            body.geometry?.materials = [material]
            lastRegion = region
            markerIDs = []
        }
        private func includes(_ point: SIMD3<Float>, in region: PainRegion) -> Bool {
            let x = abs(point.x), y = point.y
            switch region {
            case .head: return y >= 1.67
            case .neck: return y >= 1.43 && y < 1.73 && x < 0.39
            case .torso, .back: return y >= 0.84 && y < 1.57 && x < 0.34
            case .arms: return y >= 0.72 && y < 1.56 && x >= 0.20
            case .legs: return y < 1.06
            }
        }
        func frameRegion(animated: Bool) {
            lastRegion = parent.region
            // Every anatomy layer shares the same region camera. The outer shell
            // is the stable framing reference, so switching to muscle or bone
            // never changes scale or makes the anatomy appear to jump.
            let bounds = visibleBounds(for: .surface) ?? body.boundingBox
            let center = SCNVector3((bounds.min.x + bounds.max.x) / 2, (bounds.min.y + bounds.max.y) / 2, (bounds.min.z + bounds.max.z) / 2)
            let width = bounds.max.x - bounds.min.x
            let height = bounds.max.y - bounds.min.y
            let distance = max(0.62, max(width * 1.45, height * 1.72))
            SCNTransaction.begin(); SCNTransaction.animationDuration = animated ? 0.45 : 0
            body.position = SCNVector3(-center.x, -center.y, -center.z)
            camera.position = SCNVector3(0, 0, distance)
            // BodyParts3D's packaged +Z side is posterior. Face the anterior
            // surface by default and reserve the opposite view for back/waist.
            pivot.eulerAngles = SCNVector3(0, parent.region == .back ? 0 : Float.pi, 0)
            SCNTransaction.commit()
        }
        private func visibleBounds(for layer: PainAnatomyLayer) -> (min: SCNVector3, max: SCNVector3)? {
            guard usesAnatomyAsset else { return nil }
            var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            var found = false
            body.enumerateChildNodes { [weak self] node, _ in
                guard let self, node.geometry != nil, self.anatomyLayer(containing: node) == layer else { return }
                let bounds = node.boundingBox
                let corners = [
                    SCNVector3(bounds.min.x, bounds.min.y, bounds.min.z), SCNVector3(bounds.max.x, bounds.min.y, bounds.min.z),
                    SCNVector3(bounds.min.x, bounds.max.y, bounds.min.z), SCNVector3(bounds.max.x, bounds.max.y, bounds.min.z),
                    SCNVector3(bounds.min.x, bounds.min.y, bounds.max.z), SCNVector3(bounds.max.x, bounds.min.y, bounds.max.z),
                    SCNVector3(bounds.min.x, bounds.max.y, bounds.max.z), SCNVector3(bounds.max.x, bounds.max.y, bounds.max.z),
                ]
                for corner in corners {
                    let point = node.convertPosition(corner, to: self.body)
                    let vector = SIMD3<Float>(point.x, point.y, point.z)
                    minimum = simd_min(minimum, vector)
                    maximum = simd_max(maximum, vector)
                    found = true
                }
            }
            guard found, minimum.x.isFinite, maximum.x.isFinite else { return nil }
            return (SCNVector3(minimum.x, minimum.y, minimum.z), SCNVector3(maximum.x, maximum.y, maximum.z))
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
                    if let previous = drawingPoints.last { drawingRoot.addChildNode(segment(from: previous, to: point, kind: parent.kind)) }
                    else { drawingRoot.addChildNode(dot(at: point, radius: 0.009, color: parent.kind == .radiating ? .systemOrange : markerColor)) }
                    drawingPoints.append(point)
                }
            }
            if gesture.state == .ended || gesture.state == .cancelled {
                let required = parent.kind == .area ? 6 : 2
                if drawingPoints.count >= required {
                    let name = parent.kind == .area ? "三维表面圈选范围" : parent.kind == .radiating ? "三维表面放射路径" : "三维表面疼痛走向"
                    parent.marks.append(PainMark(angle: .front, kind: parent.kind, points: [], name: name, surfacePoint: nil, surfacePoints: drawingPoints))
                }
                drawingPoints = []
                drawingRoot.childNodes.forEach { $0.removeFromParentNode() }
            }
        }
        private func surfaceHit(at location: CGPoint, in view: SCNView) -> PainSurfacePoint? {
            guard let hit = view.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.all.rawValue]).first(where: {
                $0.node === body || $0.node.name?.hasPrefix(PainAnatomyLayer.surface.nodePrefix) == true
            }) else { return nil }
            let p = body.convertPosition(hit.worldCoordinates, from: nil)
            let worldEndpoint = SCNVector3(
                hit.worldCoordinates.x + hit.worldNormal.x,
                hit.worldCoordinates.y + hit.worldNormal.y,
                hit.worldCoordinates.z + hit.worldNormal.z
            )
            let endpoint = body.convertPosition(worldEndpoint, from: nil)
            let n = SCNVector3(endpoint.x - p.x, endpoint.y - p.y, endpoint.z - p.z)
            return PainSurfacePoint(x: p.x, y: p.y, z: p.z, nx: n.x, ny: n.y, nz: n.z, meshVersion: usesAnatomyAsset ? 2 : 1)
        }
        private func distance(_ a: PainSurfacePoint, _ b: PainSurfacePoint) -> Float {
            simd_distance(SIMD3(a.x, a.y, a.z), SIMD3(b.x, b.y, b.z))
        }
        func refreshMarkers() {
            let currentMeshVersion = usesAnatomyAsset ? 2 : 1
            let marks = parent.marks.filter { $0.allSurfacePoints.first?.meshVersion == currentMeshVersion }
            guard marks.map(\.id) != markerIDs else { return }
            markerIDs = marks.map(\.id)
            markerRoot.childNodes.forEach { $0.removeFromParentNode() }
            for mark in marks {
                let points = mark.allSurfacePoints
                guard !points.isEmpty else { continue }
                if mark.kind == .point { markerRoot.addChildNode(dot(at: points[0], radius: 0.014)) }
                else {
                    let sampled = sample(points, maximum: 72)
                    for pair in zip(sampled, sampled.dropFirst()) { markerRoot.addChildNode(segment(from: pair.0, to: pair.1, kind: mark.kind)) }
                    if mark.kind == .area, let first = sampled.first, let last = sampled.last {
                        markerRoot.addChildNode(segment(from: last, to: first, kind: mark.kind))
                        if sampled.count >= 3 { markerRoot.addChildNode(areaFill(sampled)) }
                    }
                    if mark.kind == .radiating, let last = sampled.last {
                        markerRoot.addChildNode(dot(at: last, radius: 0.018, color: .systemOrange))
                    }
                }
            }
        }
        private func raised(_ p: PainSurfacePoint, amount: Float = 0.004) -> SIMD3<Float> {
            let normal = SIMD3(p.nx ?? 0, p.ny ?? 0, p.nz ?? 0)
            return SIMD3(p.x, p.y, p.z) + normal * amount
        }
        private let markerColor = UIColor(red: 0.82, green: 0.25, blue: 0.22, alpha: 1)
        private func dot(at point: PainSurfacePoint, radius: CGFloat, color: UIColor? = nil) -> SCNNode {
            let sphere = SCNSphere(radius: radius)
            sphere.firstMaterial?.diffuse.contents = color ?? markerColor
            let node = SCNNode(geometry: sphere); node.simdPosition = raised(point)
            return node
        }
        private func segment(from a: PainSurfacePoint, to b: PainSurfacePoint, kind: PainMarkKind = .line) -> SCNNode {
            let start = raised(a), end = raised(b), delta = end - start
            let cylinder = SCNCylinder(radius: 0.006, height: CGFloat(simd_length(delta)))
            cylinder.firstMaterial?.diffuse.contents = kind == .radiating ? UIColor.systemOrange : markerColor
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
