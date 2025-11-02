Get-ChildItem -Recurse -File -Include *.cpp,*.h | ForEach-Object {
    clang-format -style=file -i $_.FullName
}
