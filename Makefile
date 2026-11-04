# odin-adwaita: Odin bindings for libadwaita. Consumed via -collection:adwaita=/path/to/odin-adwaita
# What every runic binding does is in house/binding.mk, a copy of house-rules'
# scripts/binding/binding.mk: this repository is public, and its runner has no house-rules.
# project.toml names the kind, the steps, the packages, the siblings and the system packages.
include house/binding.mk

# The tests run on the Amber suite's GTK (amber-gtk4, from apt.amberlinux.org), never the
# distro's libgtk-4-1: they need libgtk-4.so.1 themselves, not only through libadwaita, so the
# RUNPATH finds it in amber-gtk4's folder. They are kept in build/, where scripts/check-own-libs
# (house-rules', copied byte for byte: this repo's CI cannot read house-rules) fails one that
# loads GTK from anywhere else; project.toml's steps run it in make ci, after the tests.
GTK_BUNDLE_DIR = /usr/lib/amber-gtk4
ODIN_TEST_FLAGS += -keep-executable -extra-linker-flags:"-Wl,--push-state,--no-as-needed -lgtk-4 -Wl,--pop-state -Wl,-rpath,$(GTK_BUNDLE_DIR)"

.PHONY: check-own-libs
check-own-libs: test ## fail when a test program loads GTK from anywhere but amber-gtk4's folder
	@scripts/check-own-libs --gtk $(GTK_BUNDLE_DIR) $(foreach p,$(PACKAGES),build/$(p)_test)
