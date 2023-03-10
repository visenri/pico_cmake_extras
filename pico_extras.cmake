#[[
    This function works like "pico_generate_pio_header" but parsing previously the file with gcc preprocessor
    It generates two files:
        - A .ppio file with the preprocessed .pio file.
        - The usual header file generated by Pioasm from the .ppio file.  
]]
function(pico_generate_pio_header_pre TARGET PIO)
    _pico_init_pioasm()
    cmake_parse_arguments(pico_generate_pio_header "" "OUTPUT_DIR" "" ${ARGN} )

    if (pico_generate_pio_header_OUTPUT_DIR)
        get_filename_component(HEADER_DIR ${pico_generate_pio_header_OUTPUT_DIR} ABSOLUTE)
    else()
        set(HEADER_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    endif()

    get_filename_component(PRE_PIO ${PIO} NAME_WE)
    set(PRE_PIO "${HEADER_DIR}/${PRE_PIO}.ppio")
    #message("Will generate ${PRE_PIO}")

    get_filename_component(PIO_NAME ${PIO} NAME)
    set(HEADER "${HEADER_DIR}/${PIO_NAME}.h")
    #message("Will generate ${HEADER}")

    get_filename_component(HEADER_GEN_TARGET ${PIO} NAME_WE)
    set(HEADER_GEN_TARGET "${TARGET}_${HEADER_GEN_TARGET}_pio_h")

    add_custom_target(${HEADER_GEN_TARGET} DEPENDS ${HEADER})

    string(TOUPPER ${CMAKE_BUILD_TYPE} build_type)
    string(REPLACE " " ";" c_flags "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${build_type}}")


    set(COMPILE_DEFS "$<TARGET_PROPERTY:${TARGET},COMPILE_DEFINITIONS>")
    set(INTERFACE_COMPILE_DEFS "$<TARGET_PROPERTY:${TARGET},INTERFACE_COMPILE_DEFINITIONS>")

    set(INCLUDE_DIRS "$<TARGET_PROPERTY:${TARGET},INCLUDE_DIRECTORIES>")
    set(INTERFACE_INCLUDE_DIRS "$<TARGET_PROPERTY:${TARGET},INTERFACE_INCLUDE_DIRECTORIES>")


    add_custom_command(OUTPUT ${HEADER}
            DEPENDS ${PIO}
            IMPLICIT_DEPENDS C ${PIO}   #Let cmake gather the included files in the PIO file
            COMMAND ${CMAKE_C_COMPILER}
            "$<$<BOOL:${COMPILE_DEFS}>:-D$<JOIN:${COMPILE_DEFS},;-D>>"
            "$<$<BOOL:${INTERFACE_COMPILE_DEFS}>:-D$<JOIN:${INTERFACE_COMPILE_DEFS},;-D>>"
            "$<$<BOOL:${INCLUDE_DIRS}>:-I$<JOIN:${INCLUDE_DIRS},;-I>>"
            "$<$<BOOL:${INTERFACE_INCLUDE_DIRS}>:-I$<JOIN:${INTERFACE_INCLUDE_DIRS},;-I>>"
            ${c_flags}
            -x assembler-with-cpp   # Handle file as asm with preprocessing, otherwise it tries to link the file (-x c seems to also work just fine)
            -P      # Inhibit generation of linemarkers
            -CC     # Keep comments (c style comments, assembler comments (;) are always kept)
            -E ${PIO} -o ${PRE_PIO}
            #-traditional # Keep comments and spaces intact, but has side effects!: Lacks many features, see:
            # https://gcc.gnu.org/onlinedocs/gcc-3.2.3/cpp/Traditional-Mode.html https://gcc.gnu.org/onlinedocs/cpp/Traditional-Mode.html
            COMMAND_EXPAND_LISTS
            VERBATIM
            COMMAND Pioasm -o c-sdk ${PRE_PIO} ${HEADER}
            )
    add_dependencies(${TARGET} ${HEADER_GEN_TARGET})

    get_target_property(target_type ${TARGET} TYPE)
    if ("EXECUTABLE" STREQUAL "${target_type}")
        target_include_directories(${TARGET} PRIVATE ${HEADER_DIR})
    else()
        target_include_directories(${TARGET} INTERFACE ${HEADER_DIR})
    endif()
endfunction()
