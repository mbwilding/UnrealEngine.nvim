#include "NeovimSourceCodeAccessModule.h"
#include "Features/IModularFeatures.h"
#include "Modules/ModuleManager.h"

IMPLEMENT_MODULE(FNeovimSourceCodeAccessModule, NeovimSourceCodeAccess);

void FNeovimSourceCodeAccessModule::StartupModule()
{
    IModularFeatures::Get().RegisterModularFeature(TEXT("SourceCodeAccessor"), &NeovimSourceCodeAccessor);
}

void FNeovimSourceCodeAccessModule::ShutdownModule()
{
    IModularFeatures::Get().UnregisterModularFeature(TEXT("SourceCodeAccessor"), &NeovimSourceCodeAccessor);
}

FNeovimSourceCodeAccessor& FNeovimSourceCodeAccessModule::GetAccessor()
{
    return NeovimSourceCodeAccessor;
}
