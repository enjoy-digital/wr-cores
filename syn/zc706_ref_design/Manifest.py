board  = "zc706"
target = "xilinx"
action = "synthesis"

syn_device = "xc7z045"
syn_grade = "-2"
syn_package = "ffg900"

syn_top = "zc706_ref_top"
syn_project = "zc706_ref_top"
syn_tool = "vivado"

files = [
    "zc706_ref_design.xdc",
]

modules = {
    "local" : [
        "../../top/zc706_ref_design/",
    ],
}

