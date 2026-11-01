extends TestCase
## Tests for the Constants class.


## SHADE table has the five expected values.
func test_shade_values() -> void:
	assert_near(Constants.SHADE["WHITE"], 0.99, 0.0001, "WHITE")
	assert_near(Constants.SHADE["LIGHT"], 0.86, 0.0001, "LIGHT")
	assert_near(Constants.SHADE["FLAT"], 0.75, 0.0001, "FLAT")
	assert_near(Constants.SHADE["MID"], 0.52, 0.0001, "MID")
	assert_near(Constants.SHADE["DARK"], 0.35, 0.0001, "DARK")


## Item id lists have the expected sizes and contents.
func test_item_lists() -> void:
	assert_eq(Constants.SHAPE_IDS.size(), 11, "shape count")
	assert_eq(Constants.ELEMENT_IDS.size(), 8, "element count")
	assert_eq(Constants.DECAL_IDS.size(), 7, "decal count")
	assert_true("marble_start" in Constants.ELEMENT_IDS, "marble_start present")
