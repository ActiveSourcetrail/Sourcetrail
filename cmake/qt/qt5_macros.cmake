function(qt5_generate_deploy_script)
	set(no_value_options "")
	set(single_value_options
		CONTENT
		OUTPUT_SCRIPT
		TARGET
	)
	set(multi_value_options "")
	cmake_parse_arguments(PARSE_ARGV 0 arg
		"${no_value_options}" "${single_value_options}" "${multi_value_options}"
	)
	string(MAKE_C_IDENTIFIER "${arg_TAGET}" target_id)

    string(SHA1 args_hash "${ARGV}")
    string(SUBSTRING "${args_hash}" 0 10 short_hash)

	set(deploy_script "${CMAKE_BINARY_DIR}/deploy_${target_id}_${short_hash}-$<CONFIG>")
	string(APPEND deploy_script ".cmake")
	set(${arg_OUTPUT_SCRIPT} "${deploy_script}" PARENT_SCOPE)

	configure_file(
		"${CMAKE_SOURCE_DIR}/cmake/qt/qt5_deploy_support.cmake.in"
		"${CMAKE_BINARY_DIR}/qt5_deploy_support.cmake.generate.in"
		@ONLY
	)

	file(GENERATE
		OUTPUT "${CMAKE_BINARY_DIR}/qt5_deploy_support.cmake"
		INPUT "${CMAKE_BINARY_DIR}/qt5_deploy_support.cmake.generate.in"
	)

	set(boiler_plate "include(${CMAKE_BINARY_DIR}/qt5_deploy_support.cmake)\n")

	list(TRANSFORM arg_CONTENT REPLACE "\\$" "\$")

	file(GENERATE OUTPUT ${deploy_script} CONTENT "${boiler_plate}${arg_CONTENT}")
endfunction()