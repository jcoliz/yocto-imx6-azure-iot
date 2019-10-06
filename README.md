# yocto-imx6-azure-iot

Yocto CI/CD for Azure Pipelines, building SolidRun iMX6, connecting to Azure IoT

# Goals

* Use [Azure Pipelines](https://azure.microsoft.com/en-us/services/devops/pipelines/) to build a Yocto layer
* Create images for [SolidRun Hummingboard Edge](https://www.solid-run.com/nxp-family/hummingboard/) iMX6 single-board computer
* Upon boot, connects to [Azure IoT DPS](https://docs.microsoft.com/en-us/azure/iot-dps/about-iot-dps) to provision an identity in Azure IoT Hub.
