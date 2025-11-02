#pragma once

#include "Modules/ModuleInterface.h"
#include "NeovimSourceCodeAccessor.h"

class FNeovimSourceCodeAccessModule : public IModuleInterface
{
  public:
    virtual void StartupModule() override;
    virtual void ShutdownModule() override;
    FNeovimSourceCodeAccessor& GetAccessor();

  private:
    FNeovimSourceCodeAccessor NeovimSourceCodeAccessor;
};
