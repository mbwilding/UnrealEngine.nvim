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
    // Prefer sending files to an existing Neovim instance if $NVIM is set
    const FString EnvValue = FPlatformMisc::GetEnvironmentVariable(TEXT("NVIM"));
    const bool bHasServer = !EnvValue.IsEmpty();

    FProcHandle ProcHandle;
    if (bHasServer)
    {
        // Build: nvim --server "$NVIM" --remote <Arguments>
        FString RemoteArgs = FString::Printf(TEXT("--server \"%s\" --remote %s"), *EnvValue, Arguments);
        ProcHandle = FPlatformProcess::CreateProc(
            TEXT("nvim"),
            *RemoteArgs,
            true,
            false,
            false,
            nullptr,
            0,
            nullptr,
            nullptr);
    }

    if (!ProcHandle.IsValid())
    {
        ProcHandle = FPlatformProcess::CreateProc(
            TEXT("nvim"),
            Arguments,
            true,
            false,
            false,
            nullptr,
            0,
            nullptr,
            nullptr);
    }

    if (!ProcHandle.IsValid())
    {
        UE_LOG(LogNeovimSourceCodeAccess, Warning, TEXT("Failed to launch Neovim with arguments: %s"), Arguments);
        return false;
    }

    UE_LOG(LogNeovimSourceCodeAccess, Log, TEXT("Successfully launched Neovim with arguments: %s"), Arguments);
    return true;
}
#undef LOCTEXT_NAMESPACE
