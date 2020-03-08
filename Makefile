.PHONY: run
run: main
	cat sys.f - | ./main

main: main.asm impl.asm bootstrap.asm sys.f
	fasm $< $@

.PHONY: clean
clean:
	rm -f main
