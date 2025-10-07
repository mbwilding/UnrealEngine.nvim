#include "NeovimSourceCodeAccessor.h"
#include "HAL/PlatformProcess.h"
#include "Internationalization/Internationalization.h"
#include "Linux/LinuxPlatformProcess.h"
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
    return true;
}

bool FNeovimSourceCodeAccessor::OpenSolutionAtPath(const FString &InSolutionPath)
{
    FString Path = FPaths::GetPath(InSolutionPath);
    FPlatformProcess::ExploreFolder(*Path);

    return true;
}

bool FNeovimSourceCodeAccessor::DoesSolutionExist() const
{
    return false;
}

bool FNeovimSourceCodeAccessor::OpenFileAtLine(const FString &FullPath, int32 LineNumber, int32 ColumnNumber)
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

    return LaunchNeovim(*Arguments);
}

bool FNeovimSourceCodeAccessor::OpenSourceFiles(const TArray<FString> &AbsoluteSourcePaths)
{
    auto files = AbsoluteSourcePaths.Num();
    if (files == 0)
        return false;

    FString Arguments;
    for (const FString &Path : AbsoluteSourcePaths)
    {
        if (!Arguments.IsEmpty())
            Arguments += TEXT(" ");

        Arguments += FString::Printf(TEXT("\"%s\""), *Path);
    }

    return LaunchNeovim(*Arguments);
}

bool FNeovimSourceCodeAccessor::AddSourceFiles(const TArray<FString> &AbsoluteSourcePaths, const TArray<FString> &AvailableModules)
{
    return false;
}

bool FNeovimSourceCodeAccessor::SaveAllOpenDocuments() const
{
    return false;
}

void FNeovimSourceCodeAccessor::Tick(const float DeltaTime)
{
}

bool FNeovimSourceCodeAccessor::LaunchNeovim(const TCHAR *Arguments)
{
    const FString Application = TEXT("nvim");
    const FString RemoteServer = FPlatformMisc::GetEnvironmentVariable(TEXT("NVIM"));

    if (!RemoteServer.IsEmpty())
    {
        FString RemoteArgs = FString::Printf(TEXT("--server \"%s\" --remote %s"), *RemoteServer, Arguments);
        bool success = FPlatformProcess::ExecProcess(
            *Application,
            *RemoteArgs,
            nullptr,
            nullptr,
            nullptr);

        if (success)
        {
            UE_LOG(LogNeovimSourceCodeAccess, Log, TEXT("%s: %s %s"), *RemoteServer, *Application, *RemoteArgs);
            return true;
        }
    }

    UE_LOG(LogNeovimSourceCodeAccess, Warning, TEXT("Failed to communicate with Neovim, try launching UE via UnrealEngine.nvim"));
    return false;
}
#undef LOCTEXT_NAMESPACE
