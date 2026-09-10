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
            Text(layer == .surface
                 ? "体表用于标记疼痛位置"
                 : "(layer.rawValue)只帮助理解位置；标记时请切回体表")
                .font(.caption)
                .foregroundStyle(layer == .surface ? CX.muted : CX.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
            if editable {
                Picker("操作方式", selection: $marking) {
                    Text("转动查看").tag(false)
                    Text("标记疼处").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(layer != .surface)
                if marking {
                    Picker("标记形状", selection: $kind) {
                        ForEach(PainMarkKind.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                }
            }
            PainScene(region: region, layer: layer, marking: marking && editable, kind: kind, reset: reset, turn: turn, allowsInteraction: editable, marks: $marks, failure: $failure)
                .frame(height: 370)
                .clipShape(.rect(cornerRadius: 28))
                .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(Color.white.opacity(0.72), lineWidth: 1) }
                .accessibilityLabel("\(region.rawValue)局部三维模型；转动模式拖动旋转，标记模式点选表面")
                .accessibilityIdentifier("pain-anatomy-model")
            if let failure { Text(failure).font(.footnote).foregroundStyle(CX.coral) }
            HStack {
                Label(
                    marking && editable ? kind.instruction : "拖动旋转 · 双指缩放",
                    systemImage: marking && editable ? "hand.tap.fill" : "rotate.3d"
                )
                .font(.caption.weight(marking && editable ? .semibold : .regular))
                .foregroundStyle(marking && editable ? CX.blue : CX.muted)
                Spacer()
                Button("回正") { reset += 1 }.frame(minHeight: 44)
            }
            if editable {
                HStack {
                    if marks.contains(where: \.hasSurfaceLocation) {
                        Label("已标记 \(marks.filter(\.hasSurfaceLocation).count) 处", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CX.teal)
                    }
                    Spacer()
                    Button("撤销上一处") {
                        if let i = marks.lastIndex(where: \.hasSurfaceLocation) { marks.remove(at: i) }
                    }
                    .disabled(!marks.contains(where: \.hasSurfaceLocation))
                    .frame(minHeight: 44)
                }
            }
            Text(layer == .surface
                 ? "在\(region.rawValue)体表标记位置；位置记录不等于判断痛源。"
                 : "\(layer.rawValue)层用于帮助描述位置，标记请切回体表。")
                .font(.caption).foregroundStyle(CX.muted)
            Link("BodyParts3D 模型来源与许可", destination: URL(string: "https://dbarchive.biosciencedbc.jp/en/bodyparts3d/lic.html")!)
                .font(.caption2)
                .foregroundStyle(CX.muted)
        }
        .sensoryFeedback(.selection, trigger: marking)
        .sensoryFeedback(.impact(weight: .light), trigger: marks.count)
    }
}

/// A fixed, non-interactive render used as the four-view illustration beneath
/// the 2D marking canvas. It keeps the professional anatomy asset and removes
/// the controls and gestures of the interactive model.
struct PainAnatomyIllustrationView: View {
    let region: PainRegion
    let angle: PainAngle
    @State private var marks: [PainMark] = []
    @State private var failure: String?

    var body: some View {
        PainScene(
            region: region,
            layer: .surface,
            marking: false,
            kind: .point,
            reset: 0,
            turn: 0,
            fixedAngle: angle,
            allowsInteraction: false,
            marks: $marks,
            failure: $failure
        )
        .accessibilityHidden(true)
    }
}

private struct PainScene: UIViewRepresentable {
    let region: PainRegion
    let layer: PainAnatomyLayer
    let marking: Bool
    let kind: PainMarkKind
    let reset: Int
    let turn: Int
    var fixedAngle: PainAngle? = nil
    var allowsInteraction = true
    @Binding var marks: [PainMark]
    @Binding var failure: String?
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.95, green: 0.96, blue: 0.96, alpha: 1)
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
        let eyeRoot = SCNNode()
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
                body.addChildNode(eyeRoot)
                pivot.addChildNode(body)
                let scene = SCNScene()
                scene.rootNode.addChildNode(pivot)
                camera.camera = SCNCamera()
                camera.camera?.zNear = 0.01
                camera.camera?.zFar = 30
                camera.camera?.fieldOfView = 38
                scene.rootNode.addChildNode(camera)
                for (position, intensity, color) in [(SCNVector3(-2, 3, 4), 180.0, UIColor.white), (SCNVector3(2, 2, -3), 105.0, UIColor(red: 0.78, green: 0.84, blue: 0.88, alpha: 1))] {
                    let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni
                    light.light?.intensity = intensity; light.light?.color = color; light.position = position
                    scene.rootNode.addChildNode(light)
                }
                let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 82
                scene.rootNode.addChildNode(ambient)
                view.scene = scene; view.pointOfView = camera
                if parent.allowsInteraction {
                    let pan = UIPanGestureRecognizer(target: self, action: #selector(rotate(_:)))
                    pan.maximumNumberOfTouches = 1
                    view.addGestureRecognizer(pan)
                    view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:))))
                    view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mark(_:))))
                }
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
            eyeRoot.childNodes.forEach { $0.removeFromParentNode() }
            anatomyRoot.eulerAngles = SCNVector3Zero
            usesAnatomyAsset = false
            if let url = Bundle.main.url(forResource: region.anatomyAssetName, withExtension: "usdc"),
               let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) {
                scene.rootNode.childNodes.forEach { anatomyRoot.addChildNode($0.clone()) }
                // Blender/USD assets are Z-up; SceneKit renders Y-up.
                anatomyRoot.eulerAngles.x = -.pi / 2
                usesAnatomyAsset = true
                styleAnatomyGeometry()
                configureEyesIfNeeded()
            } else {
                applyRegion(region)
            }
            lastRegion = region
            markerIDs = []
            applyLayer(parent.layer)
        }
        func applyLayer(_ layer: PainAnatomyLayer) {
            guard usesAnatomyAsset else { return }
            eyeRoot.isHidden = layer != .surface || parent.region != .head
            body.enumerateChildNodes { node, _ in
                guard let name = node.name else { return }
                guard let nodeLayer = PainAnatomyLayer.allCases.first(where: { name.hasPrefix($0.nodePrefix) }) else { return }
                let isContextShell = nodeLayer == .surface && layer != .surface
                node.isHidden = nodeLayer != layer && !isContextShell
                // A quiet outer silhouette keeps deeper anatomy spatially
                // understandable without covering the muscle or bone detail.
                node.opacity = isContextShell ? 0.10 : 1
            }
        }
        private func configureEyesIfNeeded() {
            guard parent.region == .head,
                  parent.fixedAngle == nil || parent.fixedAngle == .front,
                  let bounds = visibleBounds(for: .surface) else { return }
            let width = bounds.max.x - bounds.min.x
            let height = bounds.max.y - bounds.min.y
            let depth = bounds.max.z - bounds.min.z
            let centerX = (bounds.min.x + bounds.max.x) / 2
            let eyeY = bounds.min.y + height * 0.60
            // Sink the eye into the open socket instead of placing a sphere in
            // front of the face. The mesh then supplies the eyelid silhouette.
            let faceZ = bounds.min.z + depth * 0.072
            let eyeSpacing = width * 0.105
            let eyeWidth = CGFloat(width * 0.050)
            let eyeHeight = CGFloat(width * 0.020)

            for direction: Float in [-1, 1] {
                let socket = SCNNode()
                socket.position = SCNVector3(centerX + direction * eyeSpacing, eyeY, faceZ)

                // Flat inset planes read as eyes from the front but have no
                // volume that can poke through the cheek when the head turns.
                let sclera = SCNPlane(width: eyeWidth, height: eyeHeight)
                sclera.cornerRadius = eyeHeight * 0.48
                sclera.firstMaterial?.diffuse.contents = UIColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1)
                sclera.firstMaterial?.roughness.contents = 0.42
                sclera.firstMaterial?.isDoubleSided = true
                let scleraNode = SCNNode(geometry: sclera)
                socket.addChildNode(scleraNode)

                let irisSize = eyeHeight * 0.68
                let iris = SCNPlane(width: irisSize, height: irisSize)
                iris.cornerRadius = irisSize / 2
                iris.firstMaterial?.diffuse.contents = UIColor(red: 0.25, green: 0.18, blue: 0.14, alpha: 1)
                iris.firstMaterial?.roughness.contents = 0.30
                iris.firstMaterial?.isDoubleSided = true
                let irisNode = SCNNode(geometry: iris)
                irisNode.position.z = -0.0008
                socket.addChildNode(irisNode)
                eyeRoot.addChildNode(socket)
            }
        }
        private func styleAnatomyGeometry() {
            body.enumerateChildNodes { [weak self] node, _ in
                guard let self, let layer = self.anatomyLayer(containing: node), let geometry = node.geometry else { return }
                let material = SCNMaterial()
                material.diffuse.contents = switch layer {
                case .surface: UIColor(red: 0.77, green: 0.68, blue: 0.60, alpha: 1)
                case .muscle: UIColor(red: 0.72, green: 0.51, blue: 0.47, alpha: 1)
                case .skeleton: UIColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 1)
                }
                material.specular.contents = UIColor(white: 0.10, alpha: 1)
                material.roughness.contents = 0.88
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
        private func isDescendant(_ node: SCNNode, of ancestor: SCNNode) -> Bool {
            var candidate: SCNNode? = node
            while let current = candidate {
                if current === ancestor { return true }
                candidate = current.parent
            }
            return false
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
            material.diffuse.contents = UIColor(red: 0.77, green: 0.68, blue: 0.60, alpha: 1)
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
            let yaw: Float = switch parent.fixedAngle {
            case .front: .pi
            case .left: .pi / 2
            case .right: -.pi / 2
            case .back: 0
            case nil: parent.region == .back ? 0 : .pi
            }
            pivot.eulerAngles = SCNVector3(0, yaw, 0)
            updateEyeVisibility()
            SCNTransaction.commit()
        }
        private func updateEyeVisibility() {
            guard parent.region == .head, parent.layer == .surface else {
                eyeRoot.opacity = 0
                return
            }
            // Fade the flat eye inserts before profile view so they never
            // detach visually from the sockets.
            let facing = max(0, -cos(pivot.eulerAngles.y))
            eyeRoot.opacity = CGFloat(min(1, max(0, (facing - 0.88) / 0.10)))
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
            updateEyeVisibility()
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
                let shouldAppend = gap.map { $0 > 0.0025 && $0 < 0.20 } ?? true
                if shouldAppend {
                    if let previous = drawingPoints.last {
                        SCNTransaction.begin()
                        SCNTransaction.disableActions = true
                        drawingRoot.addChildNode(segment(from: previous, to: point, kind: parent.kind))
                        SCNTransaction.commit()
                    }
                    else { drawingRoot.addChildNode(dot(at: point, radius: 0.009, color: parent.kind == .radiating ? .systemOrange : markerColor)) }
                    drawingPoints.append(point)
                }
            }
            if gesture.state == .ended || gesture.state == .cancelled {
                let required = parent.kind == .area ? 6 : 2
                if drawingPoints.count >= required {
                    let name = parent.kind == .area ? "三维表面圈选范围" : parent.kind == .radiating ? "三维表面放射路径" : "三维表面疼痛走向"
                    parent.marks.append(PainMark(angle: .front, kind: parent.kind, points: [], name: name, surfacePoint: nil, surfacePoints: drawingPoints))
                } else if parent.kind == .area, let center = drawingPoints.dropFirst(drawingPoints.count / 2).first ?? drawingPoints.first {
                    // A short circular gesture still means “this area”. Keep
                    // that intent as a soft patch instead of degrading it to
                    // an unrelated point marker.
                    parent.marks.append(PainMark(angle: .front, kind: .area, points: [], name: "三维表面圈选范围", surfacePoint: nil, surfacePoints: [center]))
                } else if let first = drawingPoints.first {
                    // A short stroke must still acknowledge the touch rather
                    // than silently disappearing.
                    parent.marks.append(PainMark(angle: .front, kind: .point, points: [], name: "三维表面自选位置", surfacePoint: first))
                }
                drawingPoints = []
            }
        }
        private func surfaceHit(at location: CGPoint, in view: SCNView) -> PainSurfacePoint? {
            guard parent.layer == .surface else { return nil }
            let options: [SCNHitTestOption: Any] = [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: true,
                .backFaceCulling: false
            ]
            let hits = view.hitTest(location, options: options)
            // Some BodyParts3D files put the layer name on a sibling grouping
            // node rather than a geometry ancestor. In surface mode, any visible
            // geometry under anatomyRoot is therefore a valid fallback target.
            var surfaceResult: SCNHitTestResult?
            for result in hits {
                let isNamedSurface = result.node === body || anatomyLayer(containing: result.node) == .surface
                let isVisibleAnatomy = isDescendant(result.node, of: anatomyRoot) && !isDescendant(result.node, of: eyeRoot)
                if isNamedSurface || isVisibleAnatomy {
                    surfaceResult = result
                    break
                }
            }
            guard let hit = surfaceResult else { return nil }
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
                if mark.kind == .point {
                    markerRoot.addChildNode(dot(at: points[0], radius: 0.005))
                } else if mark.kind == .area, points.count < 3 {
                    markerRoot.addChildNode(areaPatch(at: points[0]))
                }
                else {
                    let sampled = sample(points, maximum: 72)
                    for pair in zip(sampled, sampled.dropFirst()) { markerRoot.addChildNode(segment(from: pair.0, to: pair.1, kind: mark.kind)) }
                    if mark.kind == .area, let first = sampled.first, let last = sampled.last {
                        markerRoot.addChildNode(segment(from: last, to: first, kind: mark.kind))
                        if sampled.count >= 3 { markerRoot.addChildNode(areaFill(sampled)) }
                    }
                    if mark.kind == .radiating, let last = sampled.last {
                        markerRoot.addChildNode(dot(
                            at: last,
                            radius: 0.006,
                            color: UIColor(red: 0.98, green: 0.43, blue: 0.20, alpha: 0.96)
                        ))
                    }
                }
            }
            drawingRoot.childNodes.forEach { $0.removeFromParentNode() }
        }
        private func raised(_ p: PainSurfacePoint, amount: Float = 0.004) -> SIMD3<Float> {
            let normal = SIMD3(p.nx ?? 0, p.ny ?? 0, p.nz ?? 0)
            return SIMD3(p.x, p.y, p.z) + normal * amount
        }
        private let markerColor = UIColor(red: 0.91, green: 0.25, blue: 0.32, alpha: 0.92)
        private func dot(at point: PainSurfacePoint, radius: CGFloat, color: UIColor? = nil) -> SCNNode {
            let sphere = SCNSphere(radius: radius)
            sphere.firstMaterial?.diffuse.contents = color ?? markerColor
            sphere.firstMaterial?.roughness.contents = 0.72
            sphere.firstMaterial?.lightingModel = .constant
            let node = SCNNode(geometry: sphere); node.simdPosition = raised(point)
            return node
        }
        private func segment(from a: PainSurfacePoint, to b: PainSurfacePoint, kind: PainMarkKind = .line) -> SCNNode {
            let start = raised(a, amount: 0.007), end = raised(b, amount: 0.007), delta = end - start
            let radius: CGFloat = kind == .area ? 0.004 : kind == .radiating ? 0.0042 : 0.0034
            let cylinder = SCNCylinder(radius: radius, height: CGFloat(simd_length(delta)))
            let color = kind == .radiating ? UIColor(red: 0.98, green: 0.49, blue: 0.22, alpha: 0.96) : markerColor
            cylinder.firstMaterial?.diffuse.contents = color
            cylinder.firstMaterial?.emission.contents = color.withAlphaComponent(0.10)
            cylinder.firstMaterial?.roughness.contents = 0.68
            cylinder.firstMaterial?.lightingModel = .constant
            let node = SCNNode(geometry: cylinder)
            node.simdPosition = (start + end) / 2
            if simd_length(delta) > 0.0001 { node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta)) }
            return node
        }
        private func areaPatch(at point: PainSurfacePoint) -> SCNNode {
            let patch = SCNSphere(radius: 0.019)
            let color = UIColor(red: 0.91, green: 0.25, blue: 0.32, alpha: 0.28)
            patch.firstMaterial?.diffuse.contents = color
            patch.firstMaterial?.emission.contents = color.withAlphaComponent(0.08)
            patch.firstMaterial?.roughness.contents = 0.82
            patch.firstMaterial?.lightingModel = .constant
            let node = SCNNode(geometry: patch)
            let normal = SIMD3(point.nx ?? 0, point.ny ?? 0, point.nz ?? 1)
            let direction = simd_length(normal) > 0.0001 ? simd_normalize(normal) : SIMD3<Float>(0, 0, 1)
            node.simdPosition = raised(point, amount: 0.002)
            node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
            node.simdScale = SIMD3<Float>(1, 1, 0.14)
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
