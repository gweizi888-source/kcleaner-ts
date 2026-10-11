GCC_BIN="`xcrun --sdk iphoneos --find gcc`"
SDK="`xcrun --sdk iphoneos --show-sdk-path`"
# iOS 15+ / TrollStore: arm64 only (CI-friendly on current Xcode)
ARCH_FLAGS=-arch arm64

LDFLAGS	=\
	-F$(SDK)/System/Library/Frameworks/\
	-framework UIKit\
	-framework CoreFoundation\
	-framework Foundation\
	-framework CoreGraphics\
	-framework Security\
	-lobjc\
	-lsqlite3\
	-bind_at_load

GCC_ARM = $(GCC_BIN) -Os -Wimplicit -isysroot $(SDK) $(ARCH_FLAGS)

default: main.o kcleaner_ext.o list
	@$(GCC_ARM) $(LDFLAGS) main.o kcleaner_ext.o -o kcleaner_ts

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
