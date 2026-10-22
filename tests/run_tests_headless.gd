extends SceneTree

func _init():
	print("Running acceptance test matrix...")
	var matrix = preload("res://tests/test_acceptance_matrix.gd")
	var results = matrix.run_all_tests()
	print("Test Results: ", results["passed"], "/", results["total"], " passed.")
	if results["failed"] > 0:
		print("FAILURES: ", results["failures"])
		quit(1)
	else:
		print("ALL ACCEPTANCE TESTS PASSED!")
		quit(0)
