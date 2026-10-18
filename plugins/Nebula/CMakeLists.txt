cmake_minimum_required(VERSION 3.16)
project(Nebula VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX
        "$ENV{HOME}/.local/lib/qt6/qml"
        CACHE PATH "QML plugin install prefix" FORCE)
endif()

find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Qml Quick ShaderTools)
qt_standard_project_setup()

qt_add_qml_module(nebulaplugin
    URI         Nebula
    VERSION     1.0
    PLUGIN_TARGET nebulaplugin
    SOURCES
        systemstats.h
        systemstats.cpp
        sparkline.h
        sparkline.cpp
        shapes.h
        shapes.cpp
        shapepainter.h
        shapepainter.cpp
        barfield.h
        barfield.cpp
        blobfield.h
        blobfield.cpp
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Nebula
)

qt_add_shaders(nebulaplugin "nebula_barfield_shaders"
    BATCHABLE OPTIMIZED NOHLSL NOMSL
    GLSL "300es,330"
    PREFIX "/"
    FILES
        shaders/barfield.vert
        shaders/barfield.frag
        shaders/blobfield.vert
        shaders/blobfield.frag
)

target_link_libraries(nebulaplugin PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
)

install(
    DIRECTORY   "${CMAKE_CURRENT_BINARY_DIR}/Nebula/"
    DESTINATION "Nebula"
)
