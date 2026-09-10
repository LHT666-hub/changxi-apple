import XCTest
@testable import ChangXi

final class ShiyangRecommendationTests: XCTestCase {
    func testPantryIngredientsDriveTheFirstRecommendation() {
        let recommendations = ShiyangRecommendationEngine.recommendations(
            pantry: ["tomato", "egg", "scallion"],
            maxMinutes: 20,
            lowSalt: false
        )

        XCTAssertEqual(recommendations.first?.recipe.id, "tomato-scrambled-eggs")
        XCTAssertEqual(Set(recommendations.first?.missingIDs ?? []), [])
    }

    func testExcludedIngredientRemovesUnsafeRecipes() {
        let recommendations = ShiyangRecommendationEngine.recommendations(
            pantry: ["shrimp", "broccoli", "garlic"],
            excluded: ["shrimp"],
            maxMinutes: 30,
            lowSalt: true
        )

        XCTAssertFalse(recommendations.contains { recommendation in
            recommendation.recipe.ingredients.contains { $0.ingredientID == "shrimp" }
        })
    }

    func testEveryBundledRecipeHasArtworkAndCookingSteps() {
        XCTAssertGreaterThanOrEqual(ShiyangCatalog.ingredients.count, 60)
        XCTAssertGreaterThanOrEqual(ShiyangCatalog.recipes.count, 30)
        XCTAssertGreaterThanOrEqual(ShiyangCatalog.recipes.flatMap(\.steps).count, 134)
        for recipe in ShiyangCatalog.recipes {
            XCTAssertFalse(recipe.imageName.isEmpty)
            XCTAssertGreaterThanOrEqual(recipe.steps.count, 4)
            XCTAssertTrue(recipe.ingredients.contains(where: \.required))
        }
    }

    func testBundledCatalogReferencesKnownIngredients() {
        let known = Set(ShiyangCatalog.ingredients.map(\.id))
        XCTAssertEqual(known.count, ShiyangCatalog.ingredients.count)
        XCTAssertEqual(Set(ShiyangCatalog.recipes.map(\.id)).count, ShiyangCatalog.recipes.count)

        for recipe in ShiyangCatalog.recipes {
            for ingredient in recipe.ingredients {
                XCTAssertTrue(known.contains(ingredient.ingredientID), "\(recipe.id) references unknown \(ingredient.ingredientID)")
                XCTAssertTrue(Set(ingredient.alternatives).isSubset(of: known), "\(recipe.id) has an unknown alternative")
            }
            for step in recipe.steps {
                XCTAssertTrue(Set(step.ingredientIDs).isSubset(of: known), "\(recipe.id) step \(step.id) has an unknown ingredient")
            }
        }
    }

    func testNaturalLanguagePantryParsingUsesAliases() {
        let ids = Set(ShiyangCatalog.ingredientIDs(in: "冰箱里有西红柿、两个蛋，还有一点上海青"))
        XCTAssertTrue(ids.isSuperset(of: ["tomato", "egg", "bokchoy"]))
    }

    func testProfilePreferencesChangeRecommendationOrder() {
        let rice = ShiyangRecommendationEngine.recommendations(
            pantry: [],
            maxMinutes: 30,
            lowSalt: false,
            staplePreference: "米饭",
            mealContext: "在家吃",
            goal: "吃得均衡"
        )
        let noodles = ShiyangRecommendationEngine.recommendations(
            pantry: [],
            maxMinutes: 30,
            lowSalt: false,
            staplePreference: "面食",
            mealContext: "经常外卖",
            goal: "规律吃饭"
        )

        XCTAssertNotEqual(rice.first?.recipe.id, noodles.first?.recipe.id)
        XCTAssertTrue(rice.first?.recipe.ingredients.contains { $0.ingredientID == "rice" } == true)
        XCTAssertTrue(noodles.first?.recipe.ingredients.contains { $0.ingredientID == "noodles" } == true)
    }
}
