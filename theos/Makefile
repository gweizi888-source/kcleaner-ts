# Optional Theos build (macOS + Theos + iOS 15/16 SDK)
# Copies parent sources and produces KCleanerTS.tipa in ../build/

TARGET := iphone:clang:16.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = kcleaner_ts
kcleaner_ts_FILES = ../main.m ../kcleaner_ext.m ../NSTask.h
kcleaner_ts_CFLAGS = -fobjc-arc
kcleaner_ts_FRAMEWORKS = UIKit Foundation Security
kcleaner_ts_LIBRARIES = sqlite3
kcleaner_ts_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS)/makefiles/tool.mk

after-all::
	@echo "Theos tool built. For tipa packaging run: ../trollstore/pack-tipa.sh"
