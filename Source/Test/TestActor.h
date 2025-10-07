#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "TestActor.generated.h"

UCLASS()
class TEST_API ATestActor : public AActor
{
    GENERATED_BODY()

  public:
    // Sets default values for this actor's properties
    ATestActor();

  protected:
    // Called when the game starts or when spawned
    virtual void BeginPlay() override;

  public:
    // Called every frame
    virtual void Tick(float DeltaTime) override;
};
