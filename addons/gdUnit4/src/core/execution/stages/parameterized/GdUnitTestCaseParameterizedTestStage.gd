## The parameterized test case execution stage.[br]
class_name GdUnitTestCaseParamaterizedTestStage
extends IGdUnitExecutionStage


var _stage_before :IGdUnitExecutionStage = GdUnitTestCaseBeforeStage.new()
var _stage_after :IGdUnitExecutionStage = GdUnitTestCaseAfterStage.new()


## Executes a parameterized test case.[br]
## It executes synchronized following stages[br]
##  -> test_case( <test_parameters> ) [br]
func _execute(context :GdUnitExecutionContext) -> void:
	var test_case := context.test_case
	var test_parameter_index := test_case.test_parameter_index()
	var is_fail := false
	var is_error := false
	var failing_index := 0
	var parameters := GdTestParameterSet.extract_test_parameters(context.test_suite, test_case._fd)
	var error := GdTestParameterSet.validate(test_case._fd.args(), parameters)
	if not error.is_empty():
		test_case.skip(true, error)
		return
	var test_names := test_case.test_case_names();
	for test_case_index in parameters.size():
		# is test_parameter_index is set, we run this parameterized test only
		if test_parameter_index != -1 and test_parameter_index != test_case_index:
			continue
		if test_case_index >= test_names.size():
			push_error("Internal Error: The resolved test_case names has invalid size!")
			context.reports().append(GdUnitReport.new().create(GdUnitReport.FAILURE, test_case.line_number(),
			"""
			%s:
				The resolved test_case names has invalid size!
				%s
			""".dedent().trim_prefix("\n")
			% [GdAssertMessages._error("Internal Error"), GdAssertMessages._error("Please report this issue as a bug!")]))
			return
		var test_case_name = test_names[test_case_index]
		_stage_before.set_test_name(test_case_name)
		_stage_after.set_test_name(test_case_name)
		
		var test_context := GdUnitExecutionContext.of(context)
		await _stage_before.execute(test_context)
		await test_case.execute_paramaterized(parameters[test_case_index])
		await _stage_after.execute(test_context)
		# we need to clean up the reports here so they are not reported twice
		is_fail = is_fail or test_context.count_failures(false) > 0
		is_error = is_error or test_context.count_errors(false) > 0
		failing_index = test_case_index - 1
		test_context.reports().clear()
		if test_case.is_interupted():
			break
	# add report to parent execution context if failed or an error is found
	if is_fail:
		context.reports().append(GdUnitReport.new().create(GdUnitReport.FAILURE, test_case.line_number(), "Test failed at parameterized index %d." % failing_index))
	if is_error:
		context.reports().append(GdUnitReport.new().create(GdUnitReport.ABORT, test_case.line_number(), "Test aborted at parameterized index %d." % failing_index))
	await context.gc()


func set_debug_mode(debug_mode :bool = false):
	super.set_debug_mode(debug_mode)
	_stage_before.set_debug_mode(debug_mode)
	_stage_after.set_debug_mode(debug_mode)
