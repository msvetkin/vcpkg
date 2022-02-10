function(z_vcpkg_fixup_rpath_in_dir packages_dir)
    cmake_parse_arguments(PARSE_ARGV 1 arg
        ""
        ""
        "EXCLUDE_FOLDERS"
    )

    vcpkg_find_acquire_program(PATCHELF)

    # We need to iterate trough everything because we
    # can't predict where an elf file will be located
    file(GLOB root_entries LIST_DIRECTORIES TRUE "${packages_dir}/*")

    # Skip include folder and other explicitly excluded folders
    list(APPEND folders_to_skip "include" ${arg_EXCLUDE_FOLDERS})
    list(JOIN folders_to_skip "|" folders_to_skip_regex)
    set(folders_to_skip_regex "^(${folders_to_skip_regex})$")

    set(folders_to_scan)
    foreach(folder IN LISTS root_entries)
        if(NOT IS_DIRECTORY "${folder}")
            continue()
        endif()

        get_filename_component(folder_name "${folder}" NAME)
        if(folder_name MATCHES "${folders_to_skip_regex}")
            continue()
        endif()

        file(GLOB_RECURSE elf_files LIST_DIRECTORIES FALSE "${folder}/*")
        foreach(elf_file IN LISTS elf_files)
            if(IS_SYMLINK "${elf_file}")
                continue()
            endif()

            get_filename_component(elf_file_dir "${elf_file}" DIRECTORY)

            # compute path relative to lib
            file(RELATIVE_PATH relative_to_lib "${elf_file_dir}" "${packages_dir}/lib")
            if(relative_to_lib STREQUAL "")
                set(rpath "\$ORIGIN")
            else()
                set(rpath "\$ORIGIN:\$ORIGIN/${relative_to_lib}")
            endif()

            # If this fails, the file is not an elf
            execute_process(
                COMMAND "${PATCHELF}" --set-rpath "${rpath}" "${elf_file}"
                OUTPUT_QUIET
                ERROR_VARIABLE set_rpath_error
            )
            if(set_rpath_error STREQUAL "")
                message("-- Fixed rpath: ${elf_file}")
            endif()
        endforeach()
    endforeach()
endfunction()
