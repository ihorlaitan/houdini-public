#!/bin/bash
`xcrun --sdk iphoneos -f clang` -isysroot `xcrun --sdk iphoneos --show-sdk-path` -arch arm64 -o jailbreakd  -framework Foundation remote_call.c remote_ports.c remote_memory.c task_ports.c main.m
ldid -Sjailbreakd_entl.xml jailbreakd
cp jailbreakd ../houdini/
echo "[INFO]: done. I moved jailbreakd into houdini. good bye"
