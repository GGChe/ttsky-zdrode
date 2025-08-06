# signals.tcl
# ──────────────────────────────────────────────────────────────────────────────
# Only “data_in” from processing_unit_inst[0..3], nothing else.
#
# Replace “tb_processing_system_io” and “processing_unit_inst” with the exact
# names you saw in GTKWave’s hierarchy if they differ.
# ──────────────────────────────────────────────────────────────────────────────

# processing_unit_inst[0].data_in (all bits)
add wave /tb_processing_system_io/processing_unit_inst[0]/data_in[*]

# processing_unit_inst[1].data_in (all bits)
add wave /tb_processing_system_io/processing_unit_inst[1]/data_in[*]

# processing_unit_inst[2].data_in (all bits)
add wave /tb_processing_system_io/processing_unit_inst[2]/data_in[*]

# processing_unit_inst[3].data_in (all bits)
add wave /tb_processing_system_io/processing_unit_inst[3]/data_in[*]

# Finally, redraw
update
