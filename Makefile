GCC_BIN="`xcrun --sdk iphoneos --find clang`"
SDK="`xcrun --sdk iphoneos --show-sdk-path`"
IOS_TARGET=arm64-apple-ios15.0
ARCH_FLAGS=-target $(IOS_TARGET)

LDFLAGS	=\
	-F$(SDK)/System/Library/Frameworks/\
	-framework UIKit\
	-framework CoreFoundation\
	-framework Foundation\
	-framework CoreGraphics\
	-framework Security\
	-lobjc\
	-lsqlite3\
	-target $(IOS_TARGET)

GCC_ARM = $(GCC_BIN) -Os -Wimplicit -isysroot $(SDK) $(ARCH_FLAGS)

default: main.o kcleaner_ext.o
	@$(GCC_ARM) $(LDFLAGS) main.o kcleaner_ext.o -o kcleaner_ts

.PHONY: list

main.o: main.m kcleaner_ext.h
	$(GCC_ARM) -c main.m

kcleaner_ext.o: kcleaner_ext.m kcleaner_ext.h
	$(GCC_ARM) -c kcleaner_ext.m

clean:
	rm -f kcleaner_ts keychain_dumper *.o

list:
	security find-identity -pcodesigning
	@printf '\nTo codesign, please run: \n\tCER="<40 character hex string for certificate>" make codesign\n'

codesign:
	codesign -fs "$(CER)" --entitlements entitlements.xml kcleaner_ts

trollsign:
	ldid -S trollstore/entitlements.plist kcleaner_ts
