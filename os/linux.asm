format ELF64 executable

macro os_code_section {
  segment readable executable
}

macro os_data_section {
  segment readable writable
}

os_initialize:
  ret

os_print_string:
  ret

os_read_char:
  ret

os_terminate:
  ret

