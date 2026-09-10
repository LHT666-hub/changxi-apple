import SwiftUI

/// Small native illustrations for pantry cards. They stay crisp at every Dynamic Type
/// size and avoid the generic dots/capsules that made different foods look identical.
struct ShiyangIngredientArtwork: View {
    let ingredient: ShiyangIngredient

    var body: some View {
        Canvas(opaque: false, colorMode: .extendedLinear) { context, size in
            ShiyangIngredientPainter.draw(ingredient.id, in: &context, size: size)
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }
}

private enum ShiyangIngredientPainter {
    private static let leaf = Color(.displayP3, red: 0.22, green: 0.55, blue: 0.29)
    private static let leafLight = Color(.displayP3, red: 0.48, green: 0.72, blue: 0.37)
    private static let tomato = Color(.displayP3, red: 0.92, green: 0.27, blue: 0.18)
    private static let orange = Color(.displayP3, red: 0.96, green: 0.51, blue: 0.13)
    private static let cream = Color(.displayP3, red: 0.97, green: 0.88, blue: 0.67)
    private static let purple = Color(.displayP3, red: 0.43, green: 0.24, blue: 0.55)
    private static let sea = Color(.displayP3, red: 0.10, green: 0.50, blue: 0.55)
    private static let meat = Color(.displayP3, red: 0.86, green: 0.40, blue: 0.35)
    private static let grain = Color(.displayP3, red: 0.88, green: 0.65, blue: 0.25)
    private static let ink = Color(.displayP3, red: 0.25, green: 0.18, blue: 0.13)

    static func draw(_ id: String, in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
        switch id {
        case "tomato", "apple", "orange", "onion", "egg":
            drawRound(id, in: &context, rect: rect)
        case "pumpkin":
            drawPumpkin(in: &context, rect: rect)
        case "broccoli", "cauliflower":
            drawBroccoli(cauliflower: id == "cauliflower", in: &context, rect: rect)
        case "carrot":
            drawCarrot(in: &context, rect: rect)
        case "lotusroot":
            drawLotus(in: &context, rect: rect)
        case "bokchoy", "celery", "scallion", "spinach", "lettuce", "cabbage", "celtuce", "beansprout", "asparagus":
            drawLeaves(id, in: &context, rect: rect)
        case "greenpepper", "yam", "sweetpotato", "potato", "eggplant", "wintermelon", "cucumber", "zucchini", "banana", "pear":
            drawProduce(id, in: &context, rect: rect)
        case "mushroom", "woodear":
            drawMushroom(dark: id == "woodear", in: &context, rect: rect)
        case "fish", "shrimp":
            drawSeafood(shrimp: id == "shrimp", in: &context, rect: rect)
        case "chicken", "duck", "beef", "pork", "porkribs", "lamb":
            drawProtein(id, in: &context, rect: rect)
        case "tofu", "driedtofu":
            drawTofu(dried: id == "driedtofu", in: &context, rect: rect)
        case "rice", "noodles", "oats", "millet", "vermicelli", "corn":
            drawGrain(id, in: &context, rect: rect)
        case "seaweed", "kelp":
            drawSeaweed(in: &context, rect: rect)
        case "milk", "yogurt", "soymilk":
            drawDairy(id, in: &context, rect: rect)
        case "greenpea", "edamame", "peanut", "sesame", "grape", "blueberry":
            drawCluster(id, in: &context, rect: rect)
        case "ginger", "garlic":
            drawAromatic(garlic: id == "garlic", in: &context, rect: rect)
        default:
            drawLeaves(id, in: &context, rect: rect)
        }
    }

    private static func fill(_ context: inout GraphicsContext, _ rect: CGRect, _ color: Color) {
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private static func stroke(_ context: inout GraphicsContext, _ path: Path, _ color: Color, width: CGFloat = 1.4) {
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private static func drawRound(_ id: String, in context: inout GraphicsContext, rect: CGRect) {
        let bodyColor: Color = switch id {
        case "tomato": tomato
        case "apple": Color(.displayP3, red: 0.86, green: 0.22, blue: 0.18)
        case "orange": orange
        case "onion": Color(.displayP3, red: 0.69, green: 0.42, blue: 0.66)
        default: cream
        }
        let body = CGRect(x: rect.minX + 6, y: rect.minY + 9, width: rect.width - 12, height: rect.height - 13)
        fill(&context, body, bodyColor)
        fill(&context, CGRect(x: body.minX + 7, y: body.minY + 4, width: 8, height: 6), .white.opacity(0.28))
        var top = Path()
        top.move(to: CGPoint(x: rect.midX, y: body.minY + 2))
        top.addCurve(to: CGPoint(x: rect.midX - 7, y: body.minY - 4), control1: CGPoint(x: rect.midX - 1, y: body.minY - 2), control2: CGPoint(x: rect.midX - 5, y: body.minY - 4))
        top.move(to: CGPoint(x: rect.midX, y: body.minY + 2))
        top.addCurve(to: CGPoint(x: rect.midX + 7, y: body.minY - 3), control1: CGPoint(x: rect.midX + 2, y: body.minY - 2), control2: CGPoint(x: rect.midX + 5, y: body.minY - 3))
        stroke(&context, top, id == "egg" ? ink.opacity(0.45) : leaf, width: 2.4)
        if id == "egg" {
            fill(&context, CGRect(x: body.midX - 6, y: body.midY - 4, width: 12, height: 12), grain)
        }
    }

    private static func drawPumpkin(in context: inout GraphicsContext, rect: CGRect) {
        for offset in [-8.0, 0, 8.0] {
            fill(&context, CGRect(x: rect.midX - 10 + offset, y: rect.minY + 10, width: 20, height: 27), orange)
        }
        var stem = Path()
        stem.move(to: CGPoint(x: rect.midX, y: rect.minY + 11))
        stem.addLine(to: CGPoint(x: rect.midX + 2, y: rect.minY + 5))
        stroke(&context, stem, leaf, width: 3)
    }

    private static func drawBroccoli(cauliflower: Bool, in context: inout GraphicsContext, rect: CGRect) {
        let crown = cauliflower ? cream : leaf
        for point in [CGPoint(x: 13, y: 15), CGPoint(x: 21, y: 11), CGPoint(x: 29, y: 15), CGPoint(x: 18, y: 20), CGPoint(x: 26, y: 21)] {
            fill(&context, CGRect(x: rect.minX + point.x - 7, y: rect.minY + point.y - 7, width: 14, height: 14), crown)
        }
        var stalk = Path()
        stalk.move(to: CGPoint(x: rect.midX, y: rect.minY + 21))
        stalk.addLine(to: CGPoint(x: rect.midX - 5, y: rect.maxY - 2))
        stalk.move(to: CGPoint(x: rect.midX, y: rect.minY + 21))
        stalk.addLine(to: CGPoint(x: rect.midX + 6, y: rect.maxY - 2))
        stroke(&context, stalk, leafLight, width: 5)
    }

    private static func drawCarrot(in context: inout GraphicsContext, rect: CGRect) {
        var root = Path()
        root.move(to: CGPoint(x: rect.midX - 9, y: rect.minY + 12))
        root.addQuadCurve(to: CGPoint(x: rect.midX + 2, y: rect.maxY - 2), control: CGPoint(x: rect.midX + 8, y: rect.minY + 18))
        root.addQuadCurve(to: CGPoint(x: rect.midX + 9, y: rect.minY + 12), control: CGPoint(x: rect.midX + 6, y: rect.minY + 17))
        root.closeSubpath()
        context.fill(root, with: .color(orange))
        drawLeafCrown(in: &context, center: CGPoint(x: rect.midX, y: rect.minY + 12))
    }

    private static func drawLotus(in context: inout GraphicsContext, rect: CGRect) {
        fill(&context, CGRect(x: rect.minX + 4, y: rect.minY + 4, width: rect.width - 8, height: rect.height - 8), cream)
        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 3) {
            let x = rect.midX + cos(angle) * 9
            let y = rect.midY + sin(angle) * 9
            fill(&context, CGRect(x: x - 2.4, y: y - 2.4, width: 4.8, height: 4.8), ink.opacity(0.55))
        }
        fill(&context, CGRect(x: rect.midX - 2.5, y: rect.midY - 2.5, width: 5, height: 5), ink.opacity(0.55))
    }

    private static func drawLeaves(_ id: String, in context: inout GraphicsContext, rect: CGRect) {
        let stems = id == "scallion" || id == "asparagus" ? 3 : 2
        for index in 0..<stems {
            let x = rect.midX + CGFloat(index - stems / 2) * 7
            var stem = Path()
            stem.move(to: CGPoint(x: rect.midX, y: rect.maxY - 3))
            stem.addCurve(to: CGPoint(x: x, y: rect.minY + 5), control1: CGPoint(x: x - 2, y: rect.midY), control2: CGPoint(x: x, y: rect.minY + 12))
            stroke(&context, stem, index.isMultiple(of: 2) ? leaf : leafLight, width: id == "scallion" ? 3 : 5)
        }
        if id != "scallion" && id != "asparagus" {
            fill(&context, CGRect(x: rect.minX + 5, y: rect.minY + 7, width: 18, height: 23), leafLight)
            fill(&context, CGRect(x: rect.midX, y: rect.minY + 4, width: 17, height: 25), leaf)
        }
    }

    private static func drawProduce(_ id: String, in context: inout GraphicsContext, rect: CGRect) {
        let color: Color = switch id {
        case "eggplant": purple
        case "greenpepper", "cucumber", "zucchini", "wintermelon": leaf
        case "banana": grain
        case "pear": leafLight
        case "sweetpotato", "potato": Color(.displayP3, red: 0.63, green: 0.39, blue: 0.25)
        default: cream
        }
        var body = Path(roundedRect: CGRect(x: rect.minX + 8, y: rect.minY + 5, width: rect.width - 16, height: rect.height - 9), cornerRadius: 12)
        if id == "banana" {
            body = Path()
            body.addArc(center: CGPoint(x: rect.midX - 1, y: rect.midY - 2), radius: 14, startAngle: .degrees(12), endAngle: .degrees(152), clockwise: false)
            stroke(&context, body, color, width: 7)
        } else {
            context.fill(body, with: .color(color))
            fill(&context, CGRect(x: rect.midX - 5, y: rect.minY + 8, width: 7, height: 10), .white.opacity(0.24))
        }
        drawLeafCrown(in: &context, center: CGPoint(x: rect.midX, y: rect.minY + 6))
    }

    private static func drawMushroom(dark: Bool, in context: inout GraphicsContext, rect: CGRect) {
        let cap = dark ? ink.opacity(0.80) : Color(.displayP3, red: 0.60, green: 0.39, blue: 0.26)
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY - 4), radius: 15, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: CGPoint(x: rect.midX - 15, y: rect.midY - 4))
        path.closeSubpath()
        context.fill(path, with: .color(cap))
        let stalk = Path(roundedRect: CGRect(x: rect.midX - 5, y: rect.midY - 3, width: 10, height: 17), cornerRadius: 4)
        context.fill(stalk, with: .color(cream))
    }

    private static func drawSeafood(shrimp: Bool, in context: inout GraphicsContext, rect: CGRect) {
        if shrimp {
            var path = Path()
            path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: 13, startAngle: .degrees(235), endAngle: .degrees(70), clockwise: false)
            stroke(&context, path, meat, width: 7)
            fill(&context, CGRect(x: rect.midX + 7, y: rect.midY - 12, width: 4, height: 4), ink)
        } else {
            var fish = Path()
            fish.move(to: CGPoint(x: rect.minX + 6, y: rect.midY))
            fish.addQuadCurve(to: CGPoint(x: rect.maxX - 10, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.minY + 3))
            fish.addQuadCurve(to: CGPoint(x: rect.minX + 6, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY - 3))
            fish.closeSubpath()
            context.fill(fish, with: .color(sea))
            var tail = Path()
            tail.move(to: CGPoint(x: rect.maxX - 10, y: rect.midY))
            tail.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY + 8))
            tail.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 8))
            tail.closeSubpath()
            context.fill(tail, with: .color(sea.opacity(0.86)))
            fill(&context, CGRect(x: rect.minX + 11, y: rect.midY - 5, width: 3.5, height: 3.5), .white)
        }
    }

    private static func drawProtein(_ id: String, in context: inout GraphicsContext, rect: CGRect) {
        var cut = Path()
        cut.move(to: CGPoint(x: rect.minX + 5, y: rect.midY - 4))
        cut.addCurve(to: CGPoint(x: rect.midX + 4, y: rect.minY + 5), control1: CGPoint(x: rect.minX + 10, y: rect.minY + 6), control2: CGPoint(x: rect.midX, y: rect.minY + 4))
        cut.addCurve(to: CGPoint(x: rect.maxX - 4, y: rect.midY + 5), control1: CGPoint(x: rect.maxX - 3, y: rect.minY + 8), control2: CGPoint(x: rect.maxX - 2, y: rect.midY))
        cut.addCurve(to: CGPoint(x: rect.minX + 5, y: rect.midY - 4), control1: CGPoint(x: rect.midX, y: rect.maxY - 2), control2: CGPoint(x: rect.minX + 5, y: rect.maxY - 7))
        cut.closeSubpath()
        context.fill(cut, with: .color(id == "chicken" || id == "duck" ? cream : meat))
        var marbling = Path()
        marbling.move(to: CGPoint(x: rect.minX + 10, y: rect.midY))
        marbling.addCurve(to: CGPoint(x: rect.maxX - 8, y: rect.midY + 2), control1: CGPoint(x: rect.midX - 4, y: rect.minY + 10), control2: CGPoint(x: rect.midX + 5, y: rect.maxY - 8))
        stroke(&context, marbling, .white.opacity(0.55), width: 2)
    }

    private static func drawTofu(dried: Bool, in context: inout GraphicsContext, rect: CGRect) {
        let block = Path(roundedRect: CGRect(x: rect.minX + 5, y: rect.minY + 7, width: rect.width - 10, height: rect.height - 12), cornerRadius: 7)
        context.fill(block, with: .color(dried ? grain.opacity(0.72) : cream))
        stroke(&context, block, ink.opacity(0.20), width: 1)
        for point in [CGPoint(x: 14, y: 17), CGPoint(x: 25, y: 13), CGPoint(x: 29, y: 26)] {
            fill(&context, CGRect(x: rect.minX + point.x - 1.5, y: rect.minY + point.y - 1.5, width: 3, height: 3), ink.opacity(0.22))
        }
    }

    private static func drawGrain(_ id: String, in context: inout GraphicsContext, rect: CGRect) {
        if id == "noodles" || id == "vermicelli" {
            for index in 0..<4 {
                var strand = Path()
                strand.move(to: CGPoint(x: rect.minX + 8, y: rect.minY + 9 + CGFloat(index) * 6))
                strand.addCurve(to: CGPoint(x: rect.maxX - 5, y: rect.minY + 12 + CGFloat(index) * 6), control1: CGPoint(x: rect.midX - 6, y: rect.minY + CGFloat(index) * 9), control2: CGPoint(x: rect.midX + 4, y: rect.minY + 22 + CGFloat(index) * 3))
                stroke(&context, strand, grain, width: 2.8)
            }
        } else if id == "corn" {
            let cob = Path(roundedRect: CGRect(x: rect.midX - 9, y: rect.minY + 4, width: 18, height: rect.height - 8), cornerRadius: 9)
            context.fill(cob, with: .color(grain))
            for row in 0..<4 { for column in 0..<2 {
                fill(&context, CGRect(x: rect.midX - 6 + CGFloat(column) * 7, y: rect.minY + 8 + CGFloat(row) * 7, width: 4, height: 4), orange)
            }}
        } else {
            for row in 0..<3 { for column in 0..<4 {
                let x = rect.minX + 8 + CGFloat(column) * 8 + CGFloat(row % 2) * 2
                let y = rect.minY + 9 + CGFloat(row) * 9
                fill(&context, CGRect(x: x, y: y, width: 6, height: 8), grain.opacity(0.82 + Double(column) * 0.03))
            }}
        }
    }

    private static func drawSeaweed(in context: inout GraphicsContext, rect: CGRect) {
        for index in 0..<3 {
            var ribbon = Path()
            let x = rect.minX + 10 + CGFloat(index) * 10
            ribbon.move(to: CGPoint(x: x, y: rect.maxY - 3))
            ribbon.addCurve(to: CGPoint(x: x + 2, y: rect.minY + 4), control1: CGPoint(x: x - 9, y: rect.midY + 7), control2: CGPoint(x: x + 10, y: rect.midY - 7))
            stroke(&context, ribbon, index == 1 ? sea : leaf, width: 5)
        }
    }

    private static func drawDairy(_ id: String, in context: inout GraphicsContext, rect: CGRect) {
        let carton = Path(roundedRect: CGRect(x: rect.minX + 9, y: rect.minY + 6, width: rect.width - 18, height: rect.height - 9), cornerRadius: 6)
        context.fill(carton, with: .color(cream))
        stroke(&context, carton, sea.opacity(0.55), width: 1.3)
        var wave = Path()
        wave.move(to: CGPoint(x: rect.minX + 13, y: rect.midY + 2))
        wave.addCurve(to: CGPoint(x: rect.maxX - 13, y: rect.midY + 2), control1: CGPoint(x: rect.midX - 4, y: rect.midY - 5), control2: CGPoint(x: rect.midX + 3, y: rect.midY + 8))
        stroke(&context, wave, id == "soymilk" ? leaf : sea, width: 2)
    }

    private static func drawCluster(_ id: String, in context: inout GraphicsContext, rect: CGRect) {
        let color: Color = switch id {
        case "grape": purple
        case "blueberry": sea
        case "peanut", "sesame": grain
        default: leaf
        }
        for point in [CGPoint(x: 14, y: 13), CGPoint(x: 24, y: 12), CGPoint(x: 10, y: 23), CGPoint(x: 20, y: 22), CGPoint(x: 30, y: 22), CGPoint(x: 20, y: 31)] {
            fill(&context, CGRect(x: rect.minX + point.x - 4.5, y: rect.minY + point.y - 4.5, width: 9, height: 9), color)
        }
        drawLeafCrown(in: &context, center: CGPoint(x: rect.midX + 1, y: rect.minY + 8))
    }

    private static func drawAromatic(garlic: Bool, in context: inout GraphicsContext, rect: CGRect) {
        let color = garlic ? cream : grain.opacity(0.78)
        for point in [CGPoint(x: 13, y: 22), CGPoint(x: 21, y: 15), CGPoint(x: 28, y: 23), CGPoint(x: 21, y: 29)] {
            fill(&context, CGRect(x: rect.minX + point.x - 7, y: rect.minY + point.y - 7, width: 14, height: 14), color)
        }
        var stem = Path()
        stem.move(to: CGPoint(x: rect.midX, y: rect.minY + 9))
        stem.addLine(to: CGPoint(x: rect.midX + 2, y: rect.minY + 3))
        stroke(&context, stem, leaf, width: 2)
    }

    private static func drawLeafCrown(in context: inout GraphicsContext, center: CGPoint) {
        var crown = Path()
        crown.move(to: center)
        crown.addQuadCurve(to: CGPoint(x: center.x - 8, y: center.y - 5), control: CGPoint(x: center.x - 6, y: center.y + 1))
        crown.move(to: center)
        crown.addQuadCurve(to: CGPoint(x: center.x + 8, y: center.y - 5), control: CGPoint(x: center.x + 6, y: center.y + 1))
        crown.move(to: center)
        crown.addLine(to: CGPoint(x: center.x, y: center.y - 8))
        stroke(&context, crown, leaf, width: 2.4)
    }
}
