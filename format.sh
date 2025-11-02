find . -regex '.*\.\(cpp\|h\)' -exec clang-format -style=file -i {} \;
