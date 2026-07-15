THEOS ?= /home/gg1x/theos
TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TweaksLoader
TweaksLoader_FILES := main.m
TweaksLoader_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Wno-error
TweaksLoader_FRAMEWORKS := UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk