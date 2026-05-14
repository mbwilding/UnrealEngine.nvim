#include "NeovimSourceCodeAccessor.h"
#include "HAL/PlatformProcess.h"
#include "Internationalization/Internationalization.h"
#if PLATFORM_LINUX
#include "Linux/LinuxPlatformProcess.h"
#elif PLATFORM_WINDOWS
#include "Windows/WindowsPlatformProcess.h"
#elif PLATFORM_MAC
#include "Mac/MacPlatformProcess.h"
#endif
#include "Logging/LogMacros.h"
#include "Misc/Paths.h"

DEFINE_LOG_CATEGORY_STATIC(LogNeovimSourceCodeAccess, Log, All);

#define LOCTEXT_NAMESPACE "NeovimSourceCodeAccessor"
bool FNeovimSourceCodeAccessor::CanAccessSourceCode() const
{
    return true;
}

FName FNeovimSourceCodeAccessor::GetFName() const
{
    return FName("NeovimSourceCodeAccessor");
}

FText FNeovimSourceCodeAccessor::GetNameText() const
{
    return LOCTEXT("NeovimDisplayName", "Neovim");
}

FText FNeovimSourceCodeAccessor::GetDescriptionText() const
{
    return LOCTEXT("NeovimDisplayDesc", "Open source code files in Neovim");
}

bool FNeovimSourceCodeAccessor::OpenSolution()
{
    FString Arguments = FString::Printf(TEXT("\":Ex %s<CR>\""), *CurrentWorkingDirectory);
    return NeovimExecute(TEXT("remote-send"), *Arguments);
}

bool FNeovimSourceCodeAccessor::OpenSolutionAtPath(const FString& InSolutionPath)
{
    FString Path = FPaths::GetPath(InSolutionPath);
    FString Arguments = FString::Printf(TEXT("\":Ex %s<CR>\""), *Path);
    return NeovimExecute(TEXT("remote-send"), *Arguments);
}

bool FNeovimSourceCodeAccessor::DoesSolutionExist() const
{
    return FPaths::DirectoryExists(CurrentWorkingDirectory);
}

bool FNeovimSourceCodeAccessor::OpenFileAtLine(const FString& FullPath, int32 LineNumber, int32 ColumnNumber)
{
    if (FullPath.IsEmpty())
        return false;

    FString Arguments;

    if (LineNumber > 0)
    {
        if (ColumnNumber > 0)
        {
            Arguments = FString::Printf(TEXT("+%d:%d \"%s\""), LineNumber, ColumnNumber, *FullPath);
        }
        else
        {
            Arguments = FString::Printf(TEXT("+%d \"%s\""), LineNumber, *FullPath);
        }
    }
    else
    {
        Arguments = FString::Printf(TEXT("\"%s\""), *FullPath);
    }

    return NeovimExecute(TEXT("remote"), *Arguments);
}

bool FNeovimSourceCodeAccessor::OpenSourceFiles(const TArray<FString>& AbsoluteSourcePaths)
{
    auto files = AbsoluteSourcePaths.Num();
    if (files == 0)
        return false;

    FString Arguments;
    for (const FString& Path : AbsoluteSourcePaths)
    {
        if (!Arguments.IsEmpty())
            Arguments += TEXT(" ");

        Arguments += FString::Printf(TEXT("\"%s\""), *Path);
    }

    return NeovimExecute(TEXT("remote"), *Arguments);
}

bool FNeovimSourceCodeAccessor::AddSourceFiles(const TArray<FString>& AbsoluteSourcePaths, const TArray<FString>& AvailableModules)
{
    return false;
}

bool FNeovimSourceCodeAccessor::SaveAllOpenDocuments() const
{
    const FString Arguments = FString::Printf(TEXT("\":wa<CR>\""));
    return NeovimExecute(TEXT("remote-send"), *Arguments);
}

void FNeovimSourceCodeAccessor::Tick(const float DeltaTime)
{
}

bool FNeovimSourceCodeAccessor::NeovimExecute(const TCHAR* Command, const TCHAR* Arguments) const
{
    if (!RemoteServer.IsEmpty())
    {
        FString RemoteArgs = FString::Printf(TEXT("--server \"%s\" --%s %s"), *RemoteServer, Command, Arguments);
        bool bSuccess = FPlatformProcess::ExecProcess(
            *Application,
            *RemoteArgs,
            nullptr,
            nullptr,
            nullptr);

        if (bSuccess)
        {
            UE_LOG(LogNeovimSourceCodeAccess, Log, TEXT("%s: %s %s"), *RemoteServer, *Application, *RemoteArgs);
            return true;
        }
    }

    UE_LOG(LogNeovimSourceCodeAccess, Warning, TEXT("Failed to communicate with Neovim, try launching UE via UnrealEngine.nvim"));
    return false;
}
#undef LOCTEXT_NAMESPACE
