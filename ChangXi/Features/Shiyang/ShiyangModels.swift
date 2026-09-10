import Foundation

enum ShiyangIngredientCategory: String, CaseIterable, Identifiable, Hashable {
    case vegetable = "蔬菜"
    case protein = "肉蛋水产"
    case staple = "主食"
    case pantry = "菌菇豆品"
    case fruitDairy = "水果奶类"
    case nutCondiment = "坚果调味"

    var id: Self { self }
}

struct ShiyangIngredient: Identifiable, Hashable {
    let id: String
    let name: String
    let category: ShiyangIngredientCategory
    let symbol: String
    let aliases: [String]
}

struct ShiyangRecipeIngredient: Hashable {
    let ingredientID: String
    let amountForTwo: String
    let required: Bool
    let alternatives: [String]
}

struct ShiyangCookingStep: Identifiable, Hashable {
    let id: Int
    let title: String
    let detail: String
    let seconds: Int
    let ingredientIDs: [String]
    let symbol: String
}

struct ShiyangRecipe: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let imageName: String
    let minutes: Int
    let tags: [String]
    let ingredients: [ShiyangRecipeIngredient]
    let steps: [ShiyangCookingStep]
    let seasonalNote: String
    let personalizationNote: String
}

struct ShiyangRecommendation: Identifiable {
    let recipe: ShiyangRecipe
    let matchedIDs: [String]
    let missingIDs: [String]
    let score: Int

    var id: String { recipe.id }

    var reason: String {
        if missingIDs.isEmpty {
            return "主要食材家里都有 · 约\(recipe.minutes)分钟"
        }
        return "已有\(matchedIDs.count)样主要食材 · 还缺\(missingIDs.count)样"
    }
}

enum ShiyangCatalog {
    static let ingredients: [ShiyangIngredient] = [
        .init(id: "tomato", name: "番茄", category: .vegetable, symbol: "circle.fill", aliases: ["西红柿"]),
        .init(id: "mushroom", name: "菌菇", category: .pantry, symbol: "umbrella.fill", aliases: ["香菇", "蘑菇", "口蘑", "白玉菇"]),
        .init(id: "pumpkin", name: "南瓜", category: .vegetable, symbol: "circle.hexagongrid.fill", aliases: ["贝贝南瓜"]),
        .init(id: "bokchoy", name: "青菜", category: .vegetable, symbol: "leaf.fill", aliases: ["小青菜", "油菜", "上海青"]),
        .init(id: "broccoli", name: "西兰花", category: .vegetable, symbol: "tree.fill", aliases: ["西蓝花"]),
        .init(id: "greenpepper", name: "青椒", category: .vegetable, symbol: "capsule.fill", aliases: ["甜椒", "彩椒"]),
        .init(id: "carrot", name: "胡萝卜", category: .vegetable, symbol: "carrot.fill", aliases: ["红萝卜"]),
        .init(id: "lotusroot", name: "莲藕", category: .vegetable, symbol: "circle.grid.cross.fill", aliases: ["藕"]),
        .init(id: "yam", name: "山药", category: .vegetable, symbol: "capsule.fill", aliases: ["淮山"]),
        .init(id: "celery", name: "芹菜", category: .vegetable, symbol: "leaf.fill", aliases: ["西芹"]),
        .init(id: "onion", name: "洋葱", category: .vegetable, symbol: "circle.circle.fill", aliases: ["圆葱"]),
        .init(id: "scallion", name: "葱", category: .vegetable, symbol: "line.3.horizontal", aliases: ["小葱", "香葱"]),
        .init(id: "ginger", name: "姜", category: .vegetable, symbol: "sparkles", aliases: ["生姜"]),
        .init(id: "garlic", name: "蒜", category: .vegetable, symbol: "drop.fill", aliases: ["大蒜", "蒜瓣"]),
        .init(id: "egg", name: "鸡蛋", category: .protein, symbol: "oval.fill", aliases: ["蛋"]),
        .init(id: "beef", name: "牛肉", category: .protein, symbol: "flame.fill", aliases: ["牛肉片"]),
        .init(id: "chicken", name: "鸡肉", category: .protein, symbol: "bird.fill", aliases: ["鸡胸", "鸡腿"]),
        .init(id: "pork", name: "猪肉", category: .protein, symbol: "fork.knife", aliases: ["瘦肉", "肉片"]),
        .init(id: "porkribs", name: "排骨", category: .protein, symbol: "fork.knife", aliases: ["猪排骨"]),
        .init(id: "shrimp", name: "虾仁", category: .protein, symbol: "fish.fill", aliases: ["虾"]),
        .init(id: "fish", name: "鱼片", category: .protein, symbol: "fish.fill", aliases: ["鱼", "鲈鱼", "鳕鱼"]),
        .init(id: "tofu", name: "豆腐", category: .pantry, symbol: "square.fill", aliases: ["老豆腐", "嫩豆腐"]),
        .init(id: "woodear", name: "木耳", category: .pantry, symbol: "cloud.fill", aliases: ["黑木耳"]),
        .init(id: "rice", name: "米饭", category: .staple, symbol: "takeoutbag.and.cup.and.straw.fill", aliases: ["大米", "米"]),
        .init(id: "noodles", name: "面条", category: .staple, symbol: "lines.measurement.horizontal", aliases: ["面", "挂面"]),
        .init(id: "oats", name: "燕麦", category: .staple, symbol: "circle.grid.3x3.fill", aliases: ["燕麦片"]),
        .init(id: "sweetpotato", name: "红薯", category: .staple, symbol: "oval.fill", aliases: ["地瓜"]),
        .init(id: "corn", name: "玉米", category: .staple, symbol: "circle.grid.2x2.fill", aliases: ["苞米"]),
        .init(id: "potato", name: "土豆", category: .staple, symbol: "oval.fill", aliases: ["马铃薯"]),
        .init(id: "vermicelli", name: "粉丝", category: .staple, symbol: "lines.measurement.horizontal", aliases: ["粉条", "红薯粉"]),
        .init(id: "spinach", name: "菠菜", category: .vegetable, symbol: "leaf.fill", aliases: []),
        .init(id: "eggplant", name: "茄子", category: .vegetable, symbol: "capsule.fill", aliases: ["紫茄子"]),
        .init(id: "wintermelon", name: "冬瓜", category: .vegetable, symbol: "oval.fill", aliases: []),
        .init(id: "lettuce", name: "生菜", category: .vegetable, symbol: "leaf.fill", aliases: ["球生菜"]),
        .init(id: "greenpea", name: "青豆", category: .vegetable, symbol: "circle.grid.3x3.fill", aliases: ["豌豆"]),
        .init(id: "cucumber", name: "黄瓜", category: .vegetable, symbol: "capsule.fill", aliases: ["青瓜"]),
        .init(id: "cabbage", name: "大白菜", category: .vegetable, symbol: "leaf.fill", aliases: ["白菜"]),
        .init(id: "cauliflower", name: "花菜", category: .vegetable, symbol: "tree.fill", aliases: ["菜花", "白花椰菜"]),
        .init(id: "driedtofu", name: "香干", category: .pantry, symbol: "rectangle.fill", aliases: ["豆腐干", "豆干"]),
        .init(id: "milk", name: "牛奶", category: .fruitDairy, symbol: "waterbottle.fill", aliases: ["鲜奶"]),
        .init(id: "apple", name: "苹果", category: .fruitDairy, symbol: "apple.logo", aliases: []),
        .init(id: "banana", name: "香蕉", category: .fruitDairy, symbol: "moon.fill", aliases: []),
        .init(id: "yogurt", name: "酸奶", category: .fruitDairy, symbol: "cup.and.saucer.fill", aliases: ["无糖酸奶"]),
        .init(id: "peanut", name: "花生", category: .nutCondiment, symbol: "oval.fill", aliases: ["花生米"]),
        .init(id: "sesame", name: "芝麻", category: .nutCondiment, symbol: "circle.grid.3x3.fill", aliases: ["黑芝麻", "白芝麻"]),
        .init(id: "millet", name: "小米", category: .staple, symbol: "circle.grid.3x3.fill", aliases: ["小米粒"]),
        .init(id: "celtuce", name: "莴笋", category: .vegetable, symbol: "leaf.fill", aliases: ["莴苣", "青笋"]),
        .init(id: "seaweed", name: "紫菜", category: .pantry, symbol: "water.waves", aliases: ["海苔"]),
        .init(id: "beansprout", name: "豆芽", category: .vegetable, symbol: "leaf.fill", aliases: ["绿豆芽", "黄豆芽"]),
        .init(id: "asparagus", name: "芦笋", category: .vegetable, symbol: "line.3.horizontal", aliases: []),
        .init(id: "zucchini", name: "西葫芦", category: .vegetable, symbol: "capsule.fill", aliases: ["角瓜"]),
        .init(id: "kelp", name: "海带", category: .pantry, symbol: "water.waves", aliases: ["海带结", "昆布"]),
        .init(id: "edamame", name: "毛豆", category: .pantry, symbol: "circle.grid.3x3.fill", aliases: ["毛豆仁"]),
        .init(id: "pear", name: "梨", category: .fruitDairy, symbol: "drop.fill", aliases: ["雪梨", "鸭梨"]),
        .init(id: "orange", name: "橙子", category: .fruitDairy, symbol: "circle.fill", aliases: ["甜橙"]),
        .init(id: "grape", name: "葡萄", category: .fruitDairy, symbol: "circle.grid.3x3.fill", aliases: []),
        .init(id: "blueberry", name: "蓝莓", category: .fruitDairy, symbol: "circle.grid.3x3.fill", aliases: []),
        .init(id: "soymilk", name: "豆浆", category: .fruitDairy, symbol: "cup.and.saucer.fill", aliases: ["无糖豆浆"]),
        .init(id: "lamb", name: "羊肉", category: .protein, symbol: "flame.fill", aliases: ["羊肉片"]),
        .init(id: "duck", name: "鸭肉", category: .protein, symbol: "bird.fill", aliases: ["鸭腿", "鸭胸"])
    ]

    static let recipes: [ShiyangRecipe] = [
        .init(
            id: "tomato-mushroom-beef-noodles",
            title: "番茄菌菇牛肉面",
            subtitle: "一碗有菜有肉的暖汤面",
            imageName: "ShiyangNoodles",
            minutes: 25,
            tags: ["一锅完成", "暖胃", "面食"],
            ingredients: [
                .init(ingredientID: "noodles", amountForTwo: "180克", required: true, alternatives: ["rice"]),
                .init(ingredientID: "beef", amountForTwo: "160克", required: true, alternatives: ["chicken", "tofu"]),
                .init(ingredientID: "tomato", amountForTwo: "2个", required: true, alternatives: ["pumpkin"]),
                .init(ingredientID: "mushroom", amountForTwo: "150克", required: false, alternatives: ["woodear"]),
                .init(ingredientID: "bokchoy", amountForTwo: "200克", required: false, alternatives: ["broccoli", "celery"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: ["ginger"])
            ],
            steps: [
                .init(id: 0, title: "先把食材备好", detail: "番茄切块，菌菇撕开，青菜洗净；牛肉逆纹切薄片。", seconds: 0, ingredientIDs: ["tomato", "mushroom", "bokchoy", "beef"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "先炒香菌菇", detail: "锅中放少量油，中火把菌菇炒到边缘微黄。", seconds: 120, ingredientIDs: ["mushroom"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "炒出番茄汤汁", detail: "加入番茄翻炒，压出汤汁后添两碗热水。", seconds: 180, ingredientIDs: ["tomato"], symbol: "drop.fill"),
                .init(id: 3, title: "煮面", detail: "水开后下面，按包装时间少煮一分钟。", seconds: 300, ingredientIDs: ["noodles"], symbol: "timer"),
                .init(id: 4, title: "下牛肉和青菜", detail: "牛肉片逐片下锅，变色后放青菜，再煮一分钟。", seconds: 90, ingredientIDs: ["beef", "bokchoy"], symbol: "flame.fill"),
                .init(id: 5, title: "最后调味", detail: "尝过再放盐，撒葱花；喜欢微辣可加少量辣椒。", seconds: 0, ingredientIDs: ["scallion"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "白露后早晚转凉，热汤面更适合晚餐。",
            personalizationNote: "保留面食和微辣口味，同时补足蔬菜与优质蛋白。"
        ),
        .init(
            id: "pumpkin-egg-mushroom-rice",
            title: "南瓜鸡蛋菌菇焖饭",
            subtitle: "把家中常见食材焖成一锅",
            imageName: "ShiyangPumpkinRice",
            minutes: 30,
            tags: ["省事", "一锅饭", "软糯"],
            ingredients: [
                .init(ingredientID: "rice", amountForTwo: "160克", required: true, alternatives: ["noodles"]),
                .init(ingredientID: "pumpkin", amountForTwo: "220克", required: true, alternatives: ["sweetpotato"]),
                .init(ingredientID: "egg", amountForTwo: "2个", required: true, alternatives: ["tofu"]),
                .init(ingredientID: "mushroom", amountForTwo: "120克", required: false, alternatives: ["woodear"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "处理食材", detail: "南瓜切小块，菌菇切片，鸡蛋打散。", seconds: 0, ingredientIDs: ["pumpkin", "mushroom", "egg"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "炒软鸡蛋", detail: "少油把蛋液炒至刚凝固，盛出备用。", seconds: 90, ingredientIDs: ["egg"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "炒香南瓜菌菇", detail: "原锅加入南瓜和菌菇，翻炒两分钟。", seconds: 120, ingredientIDs: ["pumpkin", "mushroom"], symbol: "flame.fill"),
                .init(id: 3, title: "一起焖熟", detail: "加入洗好的米和适量水，小火焖至米饭熟透。", seconds: 900, ingredientIDs: ["rice"], symbol: "timer"),
                .init(id: 4, title: "拌入鸡蛋", detail: "关火后拌入鸡蛋，焖两分钟再撒葱花。", seconds: 120, ingredientIDs: ["egg", "scallion"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "南瓜在秋季香甜，适合做柔和的一锅饭。",
            personalizationNote: "食材切小后更容易入口，也方便一家人分餐。"
        ),
        .init(
            id: "green-pepper-chicken",
            title: "青椒鸡丁",
            subtitle: "鲜香下饭，也可以做成少油版",
            imageName: "ShiyangPepperChicken",
            minutes: 20,
            tags: ["快手", "下饭", "可微辣"],
            ingredients: [
                .init(ingredientID: "chicken", amountForTwo: "220克", required: true, alternatives: ["tofu", "pork"]),
                .init(ingredientID: "greenpepper", amountForTwo: "2个", required: true, alternatives: ["broccoli", "celery"]),
                .init(ingredientID: "onion", amountForTwo: "半个", required: false, alternatives: ["scallion"]),
                .init(ingredientID: "rice", amountForTwo: "150克", required: false, alternatives: ["noodles"])
            ],
            steps: [
                .init(id: 0, title: "切成同样大小", detail: "鸡肉、青椒和洋葱都切成约两厘米的小块。", seconds: 0, ingredientIDs: ["chicken", "greenpepper", "onion"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "滑炒鸡丁", detail: "锅热后少油下鸡丁，中火炒至表面变白。", seconds: 180, ingredientIDs: ["chicken"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "加入青椒", detail: "放青椒和洋葱，大火快速翻炒。", seconds: 120, ingredientIDs: ["greenpepper", "onion"], symbol: "flame.fill"),
                .init(id: 3, title: "薄薄调味", detail: "加少量生抽和水，翻匀后立即出锅。", seconds: 45, ingredientIDs: [], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "青椒清爽，适合需要快手完成的一餐。",
            personalizationNote: "辣度、主食量和用油量都可以继续调整。"
        ),
        .init(
            id: "mushroom-tofu-pot",
            title: "香菇豆腐煲",
            subtitle: "柔软暖和的植物蛋白菜",
            imageName: "ShiyangTofuPot",
            minutes: 25,
            tags: ["豆制品", "少肉", "暖菜"],
            ingredients: [
                .init(ingredientID: "tofu", amountForTwo: "300克", required: true, alternatives: ["egg"]),
                .init(ingredientID: "mushroom", amountForTwo: "160克", required: true, alternatives: ["woodear"]),
                .init(ingredientID: "bokchoy", amountForTwo: "200克", required: false, alternatives: ["broccoli", "celery"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "准备豆腐和菌菇", detail: "豆腐切厚块，菌菇切片，青菜洗净。", seconds: 0, ingredientIDs: ["tofu", "mushroom", "bokchoy"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "煎香豆腐", detail: "少油把豆腐两面煎至微黄。", seconds: 240, ingredientIDs: ["tofu"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "菌菇入锅", detail: "放入菌菇炒软，加半碗水。", seconds: 150, ingredientIDs: ["mushroom"], symbol: "drop.fill"),
                .init(id: 3, title: "小火煨入味", detail: "盖盖煨五分钟，最后放青菜。", seconds: 300, ingredientIDs: ["bokchoy"], symbol: "timer"),
                .init(id: 4, title: "尝味出锅", detail: "先尝再调味，撒上葱花即可。", seconds: 0, ingredientIDs: ["scallion"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "入秋后用煲菜承接温差，口感柔和。",
            personalizationNote: "不想吃肉时，也能保证一餐有蛋白质和蔬菜。"
        ),
        .init(
            id: "lotus-root-rib-soup",
            title: "莲藕排骨汤",
            subtitle: "清汤慢炖，适合家庭共享",
            imageName: "ShiyangLotusSoup",
            minutes: 55,
            tags: ["炖汤", "家庭餐", "清淡"],
            ingredients: [
                .init(ingredientID: "porkribs", amountForTwo: "350克", required: true, alternatives: ["chicken"]),
                .init(ingredientID: "lotusroot", amountForTwo: "300克", required: true, alternatives: ["yam"]),
                .init(ingredientID: "carrot", amountForTwo: "1根", required: false, alternatives: ["corn"]),
                .init(ingredientID: "ginger", amountForTwo: "3片", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "食材切块", detail: "莲藕和胡萝卜切滚刀块，排骨洗净。", seconds: 0, ingredientIDs: ["lotusroot", "carrot", "porkribs"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "排骨焯水", detail: "冷水下排骨，水开后撇去浮沫。", seconds: 300, ingredientIDs: ["porkribs"], symbol: "drop.fill"),
                .init(id: 2, title: "一起慢炖", detail: "加入莲藕、胡萝卜和姜，小火炖四十分钟。", seconds: 2400, ingredientIDs: ["lotusroot", "carrot", "ginger"], symbol: "timer"),
                .init(id: 3, title: "最后再放盐", detail: "出锅前尝味，少量加盐即可。", seconds: 0, ingredientIDs: [], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "秋季莲藕正当时，适合做一锅共享的清汤。",
            personalizationNote: "默认清淡少盐，也可以按家庭人数自动换算份量。"
        ),
        .init(
            id: "broccoli-shrimp",
            title: "西兰花虾仁",
            subtitle: "清爽快手的蔬菜蛋白菜",
            imageName: "ShiyangBroccoliShrimp",
            minutes: 18,
            tags: ["快手", "高蛋白", "清爽"],
            ingredients: [
                .init(ingredientID: "shrimp", amountForTwo: "200克", required: true, alternatives: ["fish", "chicken", "tofu"]),
                .init(ingredientID: "broccoli", amountForTwo: "300克", required: true, alternatives: ["bokchoy", "greenpepper"]),
                .init(ingredientID: "carrot", amountForTwo: "半根", required: false, alternatives: ["pumpkin"]),
                .init(ingredientID: "garlic", amountForTwo: "2瓣", required: false, alternatives: ["ginger"])
            ],
            steps: [
                .init(id: 0, title: "处理虾仁和蔬菜", detail: "虾仁擦干，西兰花切小朵，胡萝卜切片。", seconds: 0, ingredientIDs: ["shrimp", "broccoli", "carrot"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "西兰花焯水", detail: "沸水中焯一分钟，捞出沥干。", seconds: 60, ingredientIDs: ["broccoli"], symbol: "drop.fill"),
                .init(id: 2, title: "虾仁炒至变色", detail: "少油炒香蒜末，下虾仁炒至两面变粉。", seconds: 150, ingredientIDs: ["garlic", "shrimp"], symbol: "frying.pan.fill"),
                .init(id: 3, title: "合炒出锅", detail: "加入蔬菜，大火翻炒一分钟，薄薄调味。", seconds: 60, ingredientIDs: ["broccoli", "carrot"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "颜色清爽，适合作为一周里的快手晚餐。",
            personalizationNote: "蔬菜量比常见做法更多，虾仁也可随时换成鱼、鸡肉或豆腐。"
        ),
        .init(
            id: "tomato-scrambled-eggs",
            title: "番茄炒蛋",
            subtitle: "十几分钟就能完成的家常味",
            imageName: "ShiyangTomatoEgg",
            minutes: 15,
            tags: ["家常", "快手", "少食材"],
            ingredients: [
                .init(ingredientID: "tomato", amountForTwo: "2个", required: true, alternatives: ["greenpepper"]),
                .init(ingredientID: "egg", amountForTwo: "3个", required: true, alternatives: ["tofu"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "番茄切块，鸡蛋打散", detail: "番茄切成大小接近的块，蛋液搅匀。", seconds: 0, ingredientIDs: ["tomato", "egg"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "先炒嫩鸡蛋", detail: "锅热少油，蛋液刚凝固就盛出。", seconds: 60, ingredientIDs: ["egg"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "炒软番茄", detail: "原锅下番茄，中火炒出自然汤汁。", seconds: 150, ingredientIDs: ["tomato"], symbol: "drop.fill"),
                .init(id: 3, title: "合在一起", detail: "倒回鸡蛋翻匀，先尝味再加少量盐。", seconds: 45, ingredientIDs: ["egg", "tomato"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "不受季节限制，是家里食材不多时的稳妥选择。",
            personalizationNote: "甜咸口、汤汁多少和主食份量都可以继续修改。"
        ),
        .init(
            id: "yam-wood-ear-pork",
            title: "山药木耳炒肉片",
            subtitle: "脆嫩清爽的一盘家常菜",
            imageName: "ShiyangYamPork",
            minutes: 25,
            tags: ["家常", "蔬菜多", "清炒"],
            ingredients: [
                .init(ingredientID: "yam", amountForTwo: "250克", required: true, alternatives: ["lotusroot"]),
                .init(ingredientID: "woodear", amountForTwo: "80克", required: true, alternatives: ["mushroom"]),
                .init(ingredientID: "pork", amountForTwo: "150克", required: true, alternatives: ["chicken", "tofu"]),
                .init(ingredientID: "carrot", amountForTwo: "半根", required: false, alternatives: ["greenpepper"]),
                .init(ingredientID: "celery", amountForTwo: "1根", required: false, alternatives: ["bokchoy"])
            ],
            steps: [
                .init(id: 0, title: "切片并分开放", detail: "山药、肉和胡萝卜切薄片，木耳撕小朵。", seconds: 0, ingredientIDs: ["yam", "pork", "carrot", "woodear"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "先炒肉片", detail: "少油将肉片快速滑散，变色后盛出。", seconds: 120, ingredientIDs: ["pork"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "蔬菜保持脆嫩", detail: "山药、木耳和胡萝卜大火炒两分钟。", seconds: 120, ingredientIDs: ["yam", "woodear", "carrot"], symbol: "flame.fill"),
                .init(id: 3, title: "肉片回锅", detail: "倒回肉片和芹菜，薄薄调味后出锅。", seconds: 60, ingredientIDs: ["pork", "celery"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "秋季山药适合清炒，保留脆嫩口感。",
            personalizationNote: "肉量适中，以山药、木耳和蔬菜为主体。"
        ),
        .init(
            id: "ginger-scallion-fish",
            title: "姜葱蒸鱼片",
            subtitle: "蒸一蒸就好的清鲜晚餐",
            imageName: "ShiyangSteamedFish",
            minutes: 20,
            tags: ["蒸菜", "少油", "清鲜"],
            ingredients: [
                .init(ingredientID: "fish", amountForTwo: "300克", required: true, alternatives: ["shrimp", "tofu"]),
                .init(ingredientID: "ginger", amountForTwo: "5片", required: false, alternatives: []) ,
                .init(ingredientID: "scallion", amountForTwo: "2根", required: false, alternatives: []) ,
                .init(ingredientID: "bokchoy", amountForTwo: "200克", required: false, alternatives: ["broccoli"])
            ],
            steps: [
                .init(id: 0, title: "鱼片铺平", detail: "鱼片擦干后平铺盘中，放上姜丝。", seconds: 0, ingredientIDs: ["fish", "ginger"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "水开后上锅", detail: "蒸锅水开后放入鱼片，中火蒸六分钟。", seconds: 360, ingredientIDs: ["fish"], symbol: "timer"),
                .init(id: 2, title: "确认熟度", detail: "鱼肉变白、能轻松分开即可，不要久蒸。", seconds: 0, ingredientIDs: ["fish"], symbol: "checkmark.circle"),
                .init(id: 3, title: "放上姜葱", detail: "倒去多余汤水，放葱丝，淋少量热油和生抽。", seconds: 45, ingredientIDs: ["ginger", "scallion"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "清蒸做法不压住鱼的本味，也适合晚餐。",
            personalizationNote: "默认少油少盐，鱼片也能换成虾仁或豆腐。"
        ),
        .init(
            id: "potato-carrot-beef-stew",
            title: "土豆胡萝卜炖牛肉",
            subtitle: "一锅慢炖的家常暖菜",
            imageName: "ShiyangPotatoBeef",
            minutes: 50,
            tags: ["炖菜", "家庭餐", "家常"],
            ingredients: [
                .init(ingredientID: "beef", amountForTwo: "280克", required: true, alternatives: ["chicken", "pork"]),
                .init(ingredientID: "potato", amountForTwo: "2个", required: true, alternatives: ["yam"]),
                .init(ingredientID: "carrot", amountForTwo: "1根", required: false, alternatives: ["pumpkin"]),
                .init(ingredientID: "onion", amountForTwo: "半个", required: false, alternatives: ["scallion"]),
                .init(ingredientID: "ginger", amountForTwo: "3片", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "切成适口块", detail: "牛肉、土豆和胡萝卜切成大小接近的块。", seconds: 0, ingredientIDs: ["beef", "potato", "carrot"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "牛肉先焯水", detail: "冷水下牛肉，水开后撇去浮沫并沥干。", seconds: 300, ingredientIDs: ["beef", "ginger"], symbol: "drop.fill"),
                .init(id: 2, title: "炒香底味", detail: "少油炒香洋葱和姜，再放牛肉翻匀。", seconds: 180, ingredientIDs: ["onion", "ginger", "beef"], symbol: "frying.pan.fill"),
                .init(id: 3, title: "小火慢炖", detail: "加热水没过食材，小火炖二十五分钟。", seconds: 1500, ingredientIDs: ["beef"], symbol: "timer"),
                .init(id: 4, title: "加入根茎", detail: "放土豆和胡萝卜再炖十五分钟，尝味后薄薄调味。", seconds: 900, ingredientIDs: ["potato", "carrot"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "天气转凉时，一锅炖菜适合家庭共享。",
            personalizationNote: "根茎和牛肉同锅完成，主食份量可以相应减少。"
        ),
        .init(
            id: "chicken-mushroom-congee",
            title: "香菇鸡肉粥",
            subtitle: "柔软温热的一锅粥",
            imageName: "ShiyangChickenCongee",
            minutes: 40,
            tags: ["粥", "一锅完成", "清淡"],
            ingredients: [
                .init(ingredientID: "rice", amountForTwo: "100克", required: true, alternatives: ["oats"]),
                .init(ingredientID: "chicken", amountForTwo: "140克", required: true, alternatives: ["fish", "egg"]),
                .init(ingredientID: "mushroom", amountForTwo: "100克", required: true, alternatives: ["woodear"]),
                .init(ingredientID: "bokchoy", amountForTwo: "100克", required: false, alternatives: ["spinach"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "淘米切料", detail: "米洗净，香菇切片，鸡肉切细丝。", seconds: 0, ingredientIDs: ["rice", "mushroom", "chicken"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "先把粥煮开", detail: "米和足量清水入锅，大火煮开后转小火。", seconds: 600, ingredientIDs: ["rice"], symbol: "flame.fill"),
                .init(id: 2, title: "慢慢煮稠", detail: "小火煮二十分钟，中途搅动两次防止粘底。", seconds: 1200, ingredientIDs: ["rice"], symbol: "timer"),
                .init(id: 3, title: "加入鸡肉香菇", detail: "鸡丝和香菇入锅，煮到鸡肉完全变白。", seconds: 360, ingredientIDs: ["chicken", "mushroom"], symbol: "drop.fill"),
                .init(id: 4, title: "最后放青菜", detail: "青菜煮软后尝味，撒葱花即可。", seconds: 90, ingredientIDs: ["bokchoy", "scallion"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "早晚偏凉时，温热的粥更容易融入日常。",
            personalizationNote: "适合想吃柔软口感时，蔬菜和蛋白质仍然保留。"
        ),
        .init(
            id: "spinach-egg-noodles",
            title: "菠菜鸡蛋面",
            subtitle: "十五分钟完成的清汤面",
            imageName: "ShiyangSpinachNoodles",
            minutes: 15,
            tags: ["快手", "面食", "清淡"],
            ingredients: [
                .init(ingredientID: "noodles", amountForTwo: "180克", required: true, alternatives: ["vermicelli"]),
                .init(ingredientID: "spinach", amountForTwo: "180克", required: true, alternatives: ["bokchoy"]),
                .init(ingredientID: "egg", amountForTwo: "2个", required: true, alternatives: ["tofu"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "洗菜打蛋", detail: "菠菜洗净切段，鸡蛋打散，葱切末。", seconds: 0, ingredientIDs: ["spinach", "egg", "scallion"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "炒一份嫩蛋", detail: "少油把蛋液炒到刚凝固，先盛出。", seconds: 60, ingredientIDs: ["egg"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "清水煮面", detail: "水开后下面，按包装时间煮到合适软硬。", seconds: 300, ingredientIDs: ["noodles"], symbol: "timer"),
                .init(id: 3, title: "菠菜入锅", detail: "面快熟时放菠菜，煮到叶片变软。", seconds: 60, ingredientIDs: ["spinach"], symbol: "leaf.fill"),
                .init(id: 4, title: "放回鸡蛋", detail: "鸡蛋回锅，尝过汤味后再少量调味。", seconds: 30, ingredientIDs: ["egg"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "绿叶菜可随当地时令替换，不必固定使用菠菜。",
            personalizationNote: "保留面食满足感，用鸡蛋和一大把绿叶菜补足结构。"
        ),
        .init(
            id: "minced-pork-eggplant",
            title: "肉末茄子",
            subtitle: "少油也能入味的下饭菜",
            imageName: "ShiyangEggplantPork",
            minutes: 25,
            tags: ["家常", "下饭", "可微辣"],
            ingredients: [
                .init(ingredientID: "eggplant", amountForTwo: "2根", required: true, alternatives: ["wintermelon"]),
                .init(ingredientID: "pork", amountForTwo: "120克", required: true, alternatives: ["chicken", "tofu"]),
                .init(ingredientID: "garlic", amountForTwo: "2瓣", required: false, alternatives: ["ginger"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "茄子切条", detail: "茄子切粗条，蒜切末，肉剁成末。", seconds: 0, ingredientIDs: ["eggplant", "garlic", "pork"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "先把茄子蒸软", detail: "茄子上锅蒸至七分软，减少后续吸油。", seconds: 360, ingredientIDs: ["eggplant"], symbol: "timer"),
                .init(id: 2, title: "炒散肉末", detail: "少油炒香蒜末，下肉末炒至完全变色。", seconds: 180, ingredientIDs: ["garlic", "pork"], symbol: "frying.pan.fill"),
                .init(id: 3, title: "茄子回锅", detail: "加入蒸软的茄子和少量水，中火翻匀。", seconds: 150, ingredientIDs: ["eggplant"], symbol: "drop.fill"),
                .init(id: 4, title: "收汁出锅", detail: "薄薄调味，汤汁能裹住茄子即可撒葱出锅。", seconds: 60, ingredientIDs: ["scallion"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "茄子上市时口感柔软，适合做少油家常版。",
            personalizationNote: "先蒸后炒减少用油，辣味与主食量都可以继续调整。"
        ),
        .init(
            id: "winter-melon-shrimp-soup",
            title: "冬瓜虾仁汤",
            subtitle: "十几分钟的一碗清汤",
            imageName: "ShiyangWinterMelonShrimp",
            minutes: 18,
            tags: ["汤", "快手", "清爽"],
            ingredients: [
                .init(ingredientID: "wintermelon", amountForTwo: "300克", required: true, alternatives: ["cucumber"]),
                .init(ingredientID: "shrimp", amountForTwo: "150克", required: true, alternatives: ["fish", "egg"]),
                .init(ingredientID: "ginger", amountForTwo: "2片", required: false, alternatives: []),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "冬瓜切薄片", detail: "冬瓜去皮切片，虾仁擦干，姜切丝。", seconds: 0, ingredientIDs: ["wintermelon", "shrimp", "ginger"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "先煮冬瓜", detail: "清水与姜丝煮开，放冬瓜煮到微微透明。", seconds: 360, ingredientIDs: ["wintermelon", "ginger"], symbol: "drop.fill"),
                .init(id: 2, title: "虾仁入汤", detail: "放入虾仁，煮到卷曲变粉且中心熟透。", seconds: 150, ingredientIDs: ["shrimp"], symbol: "timer"),
                .init(id: 3, title: "清淡调味", detail: "先尝汤味，再少量放盐并撒葱花。", seconds: 0, ingredientIDs: ["scallion"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "冬瓜常见于暑热时节，也可按当地供应换成其他瓜类。",
            personalizationNote: "清汤与一份蛋白质组合，适合不想吃得厚重的一顿。"
        ),
        .init(
            id: "celery-dried-tofu",
            title: "芹菜炒香干",
            subtitle: "脆嫩爽口的豆制品家常菜",
            imageName: "ShiyangCeleryTofu",
            minutes: 15,
            tags: ["快手", "豆制品", "少肉"],
            ingredients: [
                .init(ingredientID: "celery", amountForTwo: "250克", required: true, alternatives: ["greenpepper"]),
                .init(ingredientID: "driedtofu", amountForTwo: "180克", required: true, alternatives: ["tofu"]),
                .init(ingredientID: "carrot", amountForTwo: "半根", required: false, alternatives: []),
                .init(ingredientID: "garlic", amountForTwo: "1瓣", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "全部切成细条", detail: "芹菜、香干和胡萝卜切成粗细接近的条。", seconds: 0, ingredientIDs: ["celery", "driedtofu", "carrot"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "香干先入锅", detail: "锅热少油，香干煎到边缘微黄。", seconds: 120, ingredientIDs: ["driedtofu"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "加入芹菜", detail: "放蒜、芹菜和胡萝卜，大火快速翻炒。", seconds: 120, ingredientIDs: ["celery", "carrot", "garlic"], symbol: "flame.fill"),
                .init(id: 3, title: "保持脆嫩", detail: "芹菜颜色变亮后薄薄调味，立即出锅。", seconds: 30, ingredientIDs: ["celery"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "芹菜清脆时适合快炒，避免久煮影响口感。",
            personalizationNote: "不依赖肉类也能完成一盘有豆制品和蔬菜的菜。"
        ),
        .init(
            id: "garlic-lettuce",
            title: "蒜蓉生菜",
            subtitle: "五分钟补一盘绿叶菜",
            imageName: "ShiyangGarlicLettuce",
            minutes: 8,
            tags: ["快手", "蔬菜多", "少油"],
            ingredients: [
                .init(ingredientID: "lettuce", amountForTwo: "350克", required: true, alternatives: ["bokchoy", "spinach"]),
                .init(ingredientID: "garlic", amountForTwo: "3瓣", required: false, alternatives: ["scallion"])
            ],
            steps: [
                .init(id: 0, title: "洗净沥干", detail: "生菜逐片洗净并充分沥水，蒜切末。", seconds: 0, ingredientIDs: ["lettuce", "garlic"], symbol: "drop.fill"),
                .init(id: 1, title: "小火炒香蒜", detail: "少油下蒜末，小火炒到刚有香气。", seconds: 30, ingredientIDs: ["garlic"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "大火快速翻炒", detail: "转大火放生菜，快速翻动到叶片变软。", seconds: 60, ingredientIDs: ["lettuce"], symbol: "flame.fill"),
                .init(id: 3, title: "马上出锅", detail: "少量调味后立即盛出，保留清脆口感。", seconds: 20, ingredientIDs: ["lettuce"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "绿叶菜可按当日买到的品种直接替换。",
            personalizationNote: "当主菜蔬菜不足时，可用这道快手菜灵活补齐。"
        ),
        .init(
            id: "corn-chicken-dice",
            title: "玉米鸡丁",
            subtitle: "清甜好入口的彩色小炒",
            imageName: "ShiyangCornChicken",
            minutes: 20,
            tags: ["快手", "高蛋白", "家常"],
            ingredients: [
                .init(ingredientID: "chicken", amountForTwo: "220克", required: true, alternatives: ["shrimp", "tofu"]),
                .init(ingredientID: "corn", amountForTwo: "150克", required: true, alternatives: ["greenpea"]),
                .init(ingredientID: "greenpea", amountForTwo: "80克", required: false, alternatives: ["bokchoy"]),
                .init(ingredientID: "carrot", amountForTwo: "半根", required: false, alternatives: ["pumpkin"])
            ],
            steps: [
                .init(id: 0, title: "切成小丁", detail: "鸡肉和胡萝卜切丁，玉米青豆沥干。", seconds: 0, ingredientIDs: ["chicken", "carrot", "corn", "greenpea"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "鸡丁先滑熟", detail: "锅热少油，下鸡丁炒到表面变白。", seconds: 180, ingredientIDs: ["chicken"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "蔬菜入锅", detail: "加入玉米、青豆和胡萝卜翻炒。", seconds: 120, ingredientIDs: ["corn", "greenpea", "carrot"], symbol: "flame.fill"),
                .init(id: 3, title: "添少量水", detail: "沿锅边加两勺水，盖盖焖两分钟。", seconds: 120, ingredientIDs: [], symbol: "drop.fill"),
                .init(id: 4, title: "薄芡收口", detail: "按口味轻调味，翻匀到汤汁薄薄裹住食材。", seconds: 45, ingredientIDs: [], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "冷冻玉米和青豆也能使用，方便全年作为常备组合。",
            personalizationNote: "颜色丰富、大小好入口，鸡肉也可换成虾仁或豆腐。"
        ),
        .init(
            id: "sweet-potato-oat-porridge",
            title: "红薯燕麦粥",
            subtitle: "十几分钟的温暖早餐",
            imageName: "ShiyangSweetPotatoOats",
            minutes: 18,
            tags: ["早餐", "粥", "少食材"],
            ingredients: [
                .init(ingredientID: "sweetpotato", amountForTwo: "200克", required: true, alternatives: ["pumpkin"]),
                .init(ingredientID: "oats", amountForTwo: "80克", required: true, alternatives: ["rice"]),
                .init(ingredientID: "milk", amountForTwo: "200毫升", required: false, alternatives: []),
                .init(ingredientID: "sesame", amountForTwo: "1茶匙", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "红薯切小块", detail: "红薯去皮切成一厘米小块，更容易按时煮软。", seconds: 0, ingredientIDs: ["sweetpotato"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "先煮红薯", detail: "红薯加清水煮到能用筷子轻松穿过。", seconds: 600, ingredientIDs: ["sweetpotato"], symbol: "timer"),
                .init(id: 2, title: "加入燕麦", detail: "放燕麦小火搅煮，避免粘底。", seconds: 240, ingredientIDs: ["oats"], symbol: "flame.fill"),
                .init(id: 3, title: "调到喜欢的浓度", detail: "可加入牛奶温热，不需久煮；最后撒少量芝麻。", seconds: 60, ingredientIDs: ["milk", "sesame"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "红薯常见的时节适合做早餐，南瓜也可直接替换。",
            personalizationNote: "用天然食材保留清甜，牛奶与芝麻均为可选项。"
        ),
        .init(
            id: "cabbage-tofu-vermicelli-pot",
            title: "白菜豆腐粉丝煲",
            subtitle: "一锅有菜有豆制品的暖汤菜",
            imageName: "ShiyangCabbageTofu",
            minutes: 25,
            tags: ["一锅完成", "豆制品", "暖菜"],
            ingredients: [
                .init(ingredientID: "cabbage", amountForTwo: "300克", required: true, alternatives: ["bokchoy"]),
                .init(ingredientID: "tofu", amountForTwo: "260克", required: true, alternatives: ["driedtofu"]),
                .init(ingredientID: "vermicelli", amountForTwo: "80克", required: true, alternatives: ["noodles"]),
                .init(ingredientID: "mushroom", amountForTwo: "100克", required: false, alternatives: ["woodear"]),
                .init(ingredientID: "ginger", amountForTwo: "2片", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "粉丝先泡软", detail: "粉丝用温水泡软，白菜切段，豆腐切厚块。", seconds: 300, ingredientIDs: ["vermicelli", "cabbage", "tofu"], symbol: "drop.fill"),
                .init(id: 1, title: "豆腐煎到微黄", detail: "少油把豆腐两面略煎定形。", seconds: 180, ingredientIDs: ["tofu"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "白菜菌菇铺底", detail: "白菜、菌菇和姜放入锅中，加一碗热水。", seconds: 120, ingredientIDs: ["cabbage", "mushroom", "ginger"], symbol: "square.grid.2x2"),
                .init(id: 3, title: "一起煨软", detail: "放入豆腐，小火盖盖煨五分钟。", seconds: 300, ingredientIDs: ["tofu"], symbol: "timer"),
                .init(id: 4, title: "粉丝最后放", detail: "加入粉丝煮两分钟，尝味后关火。", seconds: 120, ingredientIDs: ["vermicelli"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "大白菜供应充足时适合做一锅暖菜。",
            personalizationNote: "粉丝份量可调，豆腐和白菜仍是一餐的主体。"
        ),
        .init(
            id: "cucumber-chicken-slices",
            title: "黄瓜炒鸡片",
            subtitle: "清脆快手的一盘小炒",
            imageName: "ShiyangCucumberChicken",
            minutes: 18,
            tags: ["快手", "高蛋白", "清爽"],
            ingredients: [
                .init(ingredientID: "cucumber", amountForTwo: "2根", required: true, alternatives: ["celery"]),
                .init(ingredientID: "chicken", amountForTwo: "200克", required: true, alternatives: ["pork", "tofu"]),
                .init(ingredientID: "carrot", amountForTwo: "半根", required: false, alternatives: []),
                .init(ingredientID: "garlic", amountForTwo: "1瓣", required: false, alternatives: ["ginger"])
            ],
            steps: [
                .init(id: 0, title: "切成薄片", detail: "黄瓜、鸡肉和胡萝卜切成均匀薄片。", seconds: 0, ingredientIDs: ["cucumber", "chicken", "carrot"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "鸡片滑熟", detail: "少油下鸡片，中火炒到完全变白后盛出。", seconds: 180, ingredientIDs: ["chicken"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "蔬菜快炒", detail: "蒜末炒香，黄瓜和胡萝卜大火炒一分钟。", seconds: 60, ingredientIDs: ["garlic", "cucumber", "carrot"], symbol: "flame.fill"),
                .init(id: 3, title: "鸡片回锅", detail: "鸡片回锅翻匀，少量调味后立即盛出。", seconds: 45, ingredientIDs: ["chicken"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "黄瓜清脆时适合快炒，也可换成芹菜。",
            personalizationNote: "保留清脆口感和足量蛋白质，适合时间紧的一餐。"
        ),
        .init(
            id: "cauliflower-pork-slices",
            title: "花菜炒肉片",
            subtitle: "蔬菜为主的家常小炒",
            imageName: "ShiyangCauliflowerPork",
            minutes: 22,
            tags: ["家常", "蔬菜多", "下饭"],
            ingredients: [
                .init(ingredientID: "cauliflower", amountForTwo: "320克", required: true, alternatives: ["broccoli"]),
                .init(ingredientID: "pork", amountForTwo: "140克", required: true, alternatives: ["chicken", "tofu"]),
                .init(ingredientID: "greenpepper", amountForTwo: "1个", required: false, alternatives: ["carrot"]),
                .init(ingredientID: "garlic", amountForTwo: "2瓣", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "花菜分小朵", detail: "花菜切成均匀小朵，肉和青椒切片。", seconds: 0, ingredientIDs: ["cauliflower", "pork", "greenpepper"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "花菜先焯水", detail: "沸水中焯约一分钟，捞出充分沥干。", seconds: 60, ingredientIDs: ["cauliflower"], symbol: "drop.fill"),
                .init(id: 2, title: "炒熟肉片", detail: "少油炒香蒜末，放肉片炒到完全变色。", seconds: 150, ingredientIDs: ["garlic", "pork"], symbol: "frying.pan.fill"),
                .init(id: 3, title: "大火合炒", detail: "放花菜和青椒大火翻炒，薄薄调味后出锅。", seconds: 90, ingredientIDs: ["cauliflower", "greenpepper"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "花菜紧实新鲜时适合焯水后快炒。",
            personalizationNote: "以花菜为主体，肉片负责添味，比例可继续调整。"
        ),
        .init(
            id: "pumpkin-millet-congee",
            title: "南瓜小米粥",
            subtitle: "柔软清甜的家常早餐",
            imageName: "ShiyangPumpkinMillet",
            minutes: 28,
            tags: ["早餐", "粥", "少食材"],
            ingredients: [
                .init(ingredientID: "millet", amountForTwo: "90克", required: true, alternatives: ["rice", "oats"]),
                .init(ingredientID: "pumpkin", amountForTwo: "220克", required: true, alternatives: ["sweetpotato"]),
                .init(ingredientID: "milk", amountForTwo: "150毫升", required: false, alternatives: ["soymilk"])
            ],
            steps: [
                .init(id: 0, title: "小米洗净", detail: "小米轻轻淘洗，南瓜去皮切成小块。", seconds: 0, ingredientIDs: ["millet", "pumpkin"], symbol: "drop.fill"),
                .init(id: 1, title: "先把小米煮开", detail: "小米加足量清水，大火煮开后转小火。", seconds: 300, ingredientIDs: ["millet"], symbol: "flame.fill"),
                .init(id: 2, title: "南瓜一起慢煮", detail: "放入南瓜，小火煮到米粒开花、南瓜柔软。", seconds: 900, ingredientIDs: ["pumpkin"], symbol: "timer"),
                .init(id: 3, title: "调到合适浓度", detail: "用勺轻压部分南瓜；喜欢奶香可关火前加入牛奶或豆浆。", seconds: 60, ingredientIDs: ["milk", "soymilk"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "南瓜常见的时节可以多做一份，次日加热时补少量水。",
            personalizationNote: "主食和南瓜一锅完成，奶类或豆浆都是可选项。"
        ),
        .init(
            id: "celtuce-wood-ear-chicken",
            title: "莴笋木耳炒鸡片",
            subtitle: "脆嫩清爽的一盘快炒",
            imageName: "ShiyangCeltuceChicken",
            minutes: 20,
            tags: ["快手", "蔬菜多", "高蛋白"],
            ingredients: [
                .init(ingredientID: "celtuce", amountForTwo: "260克", required: true, alternatives: ["celery", "cucumber"]),
                .init(ingredientID: "woodear", amountForTwo: "80克", required: true, alternatives: ["mushroom"]),
                .init(ingredientID: "chicken", amountForTwo: "180克", required: true, alternatives: ["pork", "tofu"]),
                .init(ingredientID: "carrot", amountForTwo: "半根", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "食材切薄片", detail: "莴笋、鸡肉和胡萝卜切片，木耳撕成小朵。", seconds: 0, ingredientIDs: ["celtuce", "chicken", "carrot", "woodear"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "鸡片先滑熟", detail: "少油把鸡片炒到完全变白，先盛出。", seconds: 150, ingredientIDs: ["chicken"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "蔬菜大火快炒", detail: "莴笋、木耳和胡萝卜入锅，大火翻炒两分钟。", seconds: 120, ingredientIDs: ["celtuce", "woodear", "carrot"], symbol: "flame.fill"),
                .init(id: 3, title: "合炒出锅", detail: "鸡片回锅，薄薄调味后立即盛出。", seconds: 45, ingredientIDs: ["chicken"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "莴笋新鲜脆嫩时适合快炒，也可以用芹菜替换。",
            personalizationNote: "蔬菜占主要份量，鸡肉提供熟悉的家常口感。"
        ),
        .init(
            id: "seaweed-egg-drop-soup",
            title: "紫菜蛋花汤",
            subtitle: "几分钟就能完成的家常汤",
            imageName: "ShiyangSeaweedEggSoup",
            minutes: 8,
            tags: ["汤", "快手", "少食材"],
            ingredients: [
                .init(ingredientID: "seaweed", amountForTwo: "8克", required: true, alternatives: ["kelp"]),
                .init(ingredientID: "egg", amountForTwo: "2个", required: true, alternatives: ["tofu"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: []),
                .init(ingredientID: "sesame", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "紫菜撕小片", detail: "紫菜撕开，鸡蛋充分打散，葱切末。", seconds: 0, ingredientIDs: ["seaweed", "egg", "scallion"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "清水煮开", detail: "锅中水烧开，放入紫菜煮半分钟。", seconds: 30, ingredientIDs: ["seaweed"], symbol: "drop.fill"),
                .init(id: 2, title: "淋出蛋花", detail: "保持小沸，蛋液沿锅边细细淋入，停几秒再轻推。", seconds: 45, ingredientIDs: ["egg"], symbol: "flame.fill"),
                .init(id: 3, title: "尝味关火", detail: "先尝再少量调味，撒葱花；芝麻为可选。", seconds: 0, ingredientIDs: ["scallion", "sesame"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "干紫菜方便常备，适合临时为一餐加一碗汤。",
            personalizationNote: "食材少、时间短，可按当天主菜决定是否加入豆腐。"
        ),
        .init(
            id: "bean-sprout-tofu-vermicelli",
            title: "豆芽豆腐炒粉丝",
            subtitle: "一锅完成的清爽素菜",
            imageName: "ShiyangBeanSproutTofu",
            minutes: 20,
            tags: ["一锅完成", "豆制品", "少肉"],
            ingredients: [
                .init(ingredientID: "beansprout", amountForTwo: "260克", required: true, alternatives: ["cabbage"]),
                .init(ingredientID: "driedtofu", amountForTwo: "160克", required: true, alternatives: ["tofu"]),
                .init(ingredientID: "vermicelli", amountForTwo: "70克", required: true, alternatives: ["noodles"]),
                .init(ingredientID: "scallion", amountForTwo: "2根", required: false, alternatives: ["celery"]),
                .init(ingredientID: "garlic", amountForTwo: "1瓣", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "粉丝提前泡软", detail: "粉丝用温水泡软，豆芽洗净，香干切条。", seconds: 300, ingredientIDs: ["vermicelli", "beansprout", "driedtofu"], symbol: "drop.fill"),
                .init(id: 1, title: "香干先煎香", detail: "少油把香干煎到边缘微黄。", seconds: 120, ingredientIDs: ["driedtofu"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "加入豆芽", detail: "放蒜末和豆芽，大火快速翻炒。", seconds: 90, ingredientIDs: ["garlic", "beansprout"], symbol: "flame.fill"),
                .init(id: 3, title: "粉丝吸收汤汁", detail: "加入粉丝和少量水，翻匀到粉丝变软。", seconds: 120, ingredientIDs: ["vermicelli"], symbol: "timer"),
                .init(id: 4, title: "葱段收口", detail: "放葱段，薄薄调味后即可出锅。", seconds: 30, ingredientIDs: ["scallion"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "豆芽与豆制品全年常见，适合补充离线常备组合。",
            personalizationNote: "没有肉也能成一盘菜，粉丝份量可随主食安排减少。"
        ),
        .init(
            id: "asparagus-shrimp",
            title: "芦笋炒虾仁",
            subtitle: "脆嫩鲜亮的快手小炒",
            imageName: "ShiyangAsparagusShrimp",
            minutes: 16,
            tags: ["快手", "清爽", "高蛋白"],
            ingredients: [
                .init(ingredientID: "asparagus", amountForTwo: "260克", required: true, alternatives: ["broccoli", "celtuce"]),
                .init(ingredientID: "shrimp", amountForTwo: "180克", required: true, alternatives: ["chicken", "fish"]),
                .init(ingredientID: "carrot", amountForTwo: "半根", required: false, alternatives: []),
                .init(ingredientID: "garlic", amountForTwo: "1瓣", required: false, alternatives: ["ginger"])
            ],
            steps: [
                .init(id: 0, title: "芦笋切段", detail: "去掉老根后切段，虾仁擦干，胡萝卜切片。", seconds: 0, ingredientIDs: ["asparagus", "shrimp", "carrot"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "芦笋快速焯水", detail: "沸水焯四十秒后捞出沥干。", seconds: 40, ingredientIDs: ["asparagus"], symbol: "drop.fill"),
                .init(id: 2, title: "虾仁炒熟", detail: "少油炒香蒜末，放虾仁炒到卷曲变粉。", seconds: 120, ingredientIDs: ["garlic", "shrimp"], symbol: "frying.pan.fill"),
                .init(id: 3, title: "蔬菜回锅", detail: "芦笋和胡萝卜回锅，大火翻匀后薄薄调味。", seconds: 60, ingredientIDs: ["asparagus", "carrot"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "芦笋鲜嫩时适合短时间快炒，西兰花也能直接替换。",
            personalizationNote: "烹饪时间短，虾仁也可按照过敏或偏好换成鸡肉。"
        ),
        .init(
            id: "zucchini-scrambled-eggs",
            title: "西葫芦炒鸡蛋",
            subtitle: "柔软清香的家常小炒",
            imageName: "ShiyangZucchiniEgg",
            minutes: 15,
            tags: ["快手", "家常", "少食材"],
            ingredients: [
                .init(ingredientID: "zucchini", amountForTwo: "2根", required: true, alternatives: ["cucumber", "wintermelon"]),
                .init(ingredientID: "egg", amountForTwo: "3个", required: true, alternatives: ["tofu"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "切片打蛋", detail: "西葫芦切薄片，鸡蛋打散，葱切末。", seconds: 0, ingredientIDs: ["zucchini", "egg", "scallion"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "鸡蛋炒嫩", detail: "锅热少油，蛋液刚凝固就盛出。", seconds: 60, ingredientIDs: ["egg"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "西葫芦快炒", detail: "原锅放西葫芦，中大火炒到微微变软。", seconds: 120, ingredientIDs: ["zucchini"], symbol: "flame.fill"),
                .init(id: 3, title: "合炒完成", detail: "鸡蛋回锅翻匀，尝味后少量调味。", seconds: 30, ingredientIDs: ["egg"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "西葫芦鲜嫩时无需久炒，出水较多也属正常。",
            personalizationNote: "两样主食材即可完成，适合家里库存不多的时候。"
        ),
        .init(
            id: "kelp-rib-soup",
            title: "海带排骨汤",
            subtitle: "清汤慢炖的家庭汤菜",
            imageName: "ShiyangKelpRibSoup",
            minutes: 55,
            tags: ["炖汤", "家庭餐", "清淡"],
            ingredients: [
                .init(ingredientID: "kelp", amountForTwo: "180克", required: true, alternatives: ["wintermelon"]),
                .init(ingredientID: "porkribs", amountForTwo: "350克", required: true, alternatives: ["chicken", "duck"]),
                .init(ingredientID: "ginger", amountForTwo: "4片", required: false, alternatives: []),
                .init(ingredientID: "corn", amountForTwo: "1根", required: false, alternatives: ["carrot"])
            ],
            steps: [
                .init(id: 0, title: "海带充分清洗", detail: "海带结展开冲洗，排骨洗净，玉米切段。", seconds: 0, ingredientIDs: ["kelp", "porkribs", "corn"], symbol: "drop.fill"),
                .init(id: 1, title: "排骨冷水焯", detail: "排骨与两片姜冷水入锅，煮开后撇净浮沫。", seconds: 300, ingredientIDs: ["porkribs", "ginger"], symbol: "flame.fill"),
                .init(id: 2, title: "重新加热水", detail: "排骨、玉米和姜加入热水，大火煮开。", seconds: 300, ingredientIDs: ["porkribs", "corn", "ginger"], symbol: "drop.fill"),
                .init(id: 3, title: "小火慢炖", detail: "转小火炖三十分钟，再放海带继续炖十五分钟。", seconds: 2700, ingredientIDs: ["kelp"], symbol: "timer"),
                .init(id: 4, title: "最后尝味", detail: "关火前尝汤味，再决定是否少量加盐。", seconds: 0, ingredientIDs: [], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "海带干品方便储存，适合提前规划的家庭汤菜。",
            personalizationNote: "默认清汤少盐，炖汤时间较长时会自动排在有空的日子。"
        ),
        .init(
            id: "edamame-pork-steamed-egg",
            title: "毛豆肉末蒸蛋",
            subtitle: "细嫩好入口的一碗蒸菜",
            imageName: "ShiyangEdamameEgg",
            minutes: 25,
            tags: ["蒸菜", "家庭餐", "高蛋白"],
            ingredients: [
                .init(ingredientID: "egg", amountForTwo: "3个", required: true, alternatives: ["tofu"]),
                .init(ingredientID: "edamame", amountForTwo: "100克", required: true, alternatives: ["greenpea"]),
                .init(ingredientID: "pork", amountForTwo: "100克", required: false, alternatives: ["chicken", "mushroom"]),
                .init(ingredientID: "scallion", amountForTwo: "少许", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "毛豆先煮熟", detail: "毛豆仁沸水煮三分钟后沥干。", seconds: 180, ingredientIDs: ["edamame"], symbol: "drop.fill"),
                .init(id: 1, title: "蛋液兑温水", detail: "鸡蛋打散，加入约一倍温水并轻轻搅匀。", seconds: 0, ingredientIDs: ["egg"], symbol: "cup.and.saucer.fill"),
                .init(id: 2, title: "小火炒肉末", detail: "少油把肉末炒散并确认完全变色。", seconds: 150, ingredientIDs: ["pork"], symbol: "frying.pan.fill"),
                .init(id: 3, title: "中小火蒸熟", detail: "蛋液盖盘入蒸锅，中小火蒸十分钟。", seconds: 600, ingredientIDs: ["egg"], symbol: "timer"),
                .init(id: 4, title: "铺上毛豆肉末", detail: "确认蛋液凝固后铺上毛豆与肉末，撒葱花。", seconds: 0, ingredientIDs: ["edamame", "pork", "scallion"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "鲜毛豆上市时可以使用，其他时候冷冻毛豆仁也方便。",
            personalizationNote: "口感柔软，肉末为可选，也可换成香菇做成素版。"
        ),
        .init(
            id: "tomato-potato-chicken-stew",
            title: "番茄土豆炖鸡",
            subtitle: "酸香温暖的一锅家常菜",
            imageName: "ShiyangTomatoPotatoChicken",
            minutes: 38,
            tags: ["炖菜", "一锅完成", "家庭餐"],
            ingredients: [
                .init(ingredientID: "chicken", amountForTwo: "300克", required: true, alternatives: ["beef", "duck"]),
                .init(ingredientID: "tomato", amountForTwo: "2个", required: true, alternatives: ["pumpkin"]),
                .init(ingredientID: "potato", amountForTwo: "2个", required: true, alternatives: ["yam"]),
                .init(ingredientID: "onion", amountForTwo: "半个", required: false, alternatives: ["scallion"]),
                .init(ingredientID: "carrot", amountForTwo: "半根", required: false, alternatives: [])
            ],
            steps: [
                .init(id: 0, title: "全部切块", detail: "鸡肉、番茄、土豆和胡萝卜切成适口块。", seconds: 0, ingredientIDs: ["chicken", "tomato", "potato", "carrot"], symbol: "square.grid.2x2"),
                .init(id: 1, title: "鸡肉煎香", detail: "少油把鸡肉表面煎到微黄。", seconds: 240, ingredientIDs: ["chicken"], symbol: "frying.pan.fill"),
                .init(id: 2, title: "番茄炒出汁", detail: "加入洋葱和番茄，翻炒到番茄变软。", seconds: 180, ingredientIDs: ["onion", "tomato"], symbol: "drop.fill"),
                .init(id: 3, title: "加入根茎炖煮", detail: "放土豆、胡萝卜和热水，小火盖盖炖二十分钟。", seconds: 1200, ingredientIDs: ["potato", "carrot"], symbol: "timer"),
                .init(id: 4, title: "确认熟度出锅", detail: "确认鸡肉中心熟透、土豆柔软，尝味后薄薄调味。", seconds: 0, ingredientIDs: ["chicken", "potato"], symbol: "checkmark.circle.fill")
            ],
            seasonalNote: "番茄和土豆全年常见，是容易复用的一锅组合。",
            personalizationNote: "用番茄自然汤汁承接味道，鸡肉也可按库存替换。"
        )
    ]

    static func ingredient(_ id: String) -> ShiyangIngredient? {
        ingredients.first { $0.id == id }
    }

    static func recipe(_ id: String) -> ShiyangRecipe {
        recipes.first { $0.id == id } ?? recipes[0]
    }

    static func ingredientIDs(in text: String) -> [String] {
        let normalized = text.lowercased()
        return ingredients.compactMap { item in
            let names = [item.name] + item.aliases
            return names.contains { normalized.contains($0.lowercased()) } ? item.id : nil
        }
    }
}

enum ShiyangRecommendationEngine {
    static func recommendations(
        pantry: Set<String>,
        excluded: Set<String> = [],
        maxMinutes: Int,
        lowSalt: Bool,
        likesSpicy: Bool = false,
        staplePreference: String = "都可以",
        mealContext: String = "不太固定",
        goal: String = "吃得均衡"
    ) -> [ShiyangRecommendation] {
        ShiyangCatalog.recipes.compactMap { recipe in
            let ingredientIDs = Set(recipe.ingredients.map(\.ingredientID))
            guard ingredientIDs.isDisjoint(with: excluded) else { return nil }

            let matched = recipe.ingredients.filter { pantry.contains($0.ingredientID) }.map(\.ingredientID)
            let missing = recipe.ingredients.filter { $0.required && !pantry.contains($0.ingredientID) }.map(\.ingredientID)
            var score = matched.count * 14 - missing.count * 8
            score += recipe.minutes <= maxMinutes ? 12 : -min(20, recipe.minutes - maxMinutes)
            if lowSalt && recipe.tags.contains(where: { ["清淡", "少油", "清鲜"].contains($0) }) { score += 5 }
            if likesSpicy && recipe.tags.contains("可微辣") { score += 4 }
            if staplePreference == "米饭", ingredientIDs.contains("rice") { score += 12 }
            if staplePreference == "面食", ingredientIDs.contains("noodles") { score += 12 }

            switch mealContext {
            case "经常外卖", "经常食堂":
                if recipe.minutes <= 25 { score += 4 }
            case "在家吃":
                if recipe.tags.contains(where: { ["家庭餐", "一锅饭", "家常"].contains($0) }) { score += 4 }
            default:
                break
            }

            switch goal {
            case "规律吃饭":
                if recipe.minutes <= 25 { score += 5 }
            case "管理体重":
                if recipe.tags.contains(where: { ["清爽", "少油", "蒸菜", "高蛋白", "蔬菜多"].contains($0) }) { score += 7 }
            case "照顾健康情况":
                if recipe.tags.contains(where: { ["清淡", "少油", "清鲜"].contains($0) }) { score += 7 }
            default:
                let categories = Set(recipe.ingredients.compactMap { ingredient in
                    ShiyangCatalog.ingredient(ingredient.ingredientID)?.category
                })
                if categories.count >= 3 { score += 5 }
            }
            return ShiyangRecommendation(recipe: recipe, matchedIDs: matched, missingIDs: missing, score: score)
        }
        .sorted {
            if $0.score == $1.score { return $0.recipe.minutes < $1.recipe.minutes }
            return $0.score > $1.score
        }
    }
}

enum ShiyangSeason {
    static var currentSolarTerm: String {
        let components = Calendar.current.dateComponents([.month, .day], from: .now)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let terms: [(month: Int, day: Int, name: String)] = [
            (1, 5, "小寒"), (1, 20, "大寒"), (2, 4, "立春"), (2, 19, "雨水"),
            (3, 5, "惊蛰"), (3, 20, "春分"), (4, 4, "清明"), (4, 20, "谷雨"),
            (5, 5, "立夏"), (5, 21, "小满"), (6, 5, "芒种"), (6, 21, "夏至"),
            (7, 7, "小暑"), (7, 22, "大暑"), (8, 7, "立秋"), (8, 23, "处暑"),
            (9, 7, "白露"), (9, 23, "秋分"), (10, 8, "寒露"), (10, 23, "霜降"),
            (11, 7, "立冬"), (11, 22, "小雪"), (12, 7, "大雪"), (12, 21, "冬至")
        ]
        let today = month * 100 + day
        return terms.last(where: { $0.month * 100 + $0.day <= today })?.name ?? "冬至"
    }
}
