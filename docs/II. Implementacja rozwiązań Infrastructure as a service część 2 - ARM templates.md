# II. Implementacja rozwiązań Infrastructure as a service część 2 - ARM templates


## II. Configure, validate, and deploy ARM templates
An ARM template is a JSON‑formatted file that is a configuration document that defines what resources you want deployed in Azure with their configurations. You can create any resource with an ARM template.
ARM templates are a building block for deployment automation. Using ARM templates, you can parameterize the configuration elements for resources defined in an ARM template. You can use parameters for commonly changed configuration elements such as virtual machine names, virtual network names, storage account names, and more. You can then use that same ARM template repeatedly to deploy the environment defined in the template, but using different parameters to customize each environment at deployment time. So for example, having one set of parameters for production, another for QA, and another for dev, still using the same ARM template, but with different parameters, providing consistency to your deployments.

From a process standpoint, you create an ARM template and then an ARM template is submitted to Azure Resource Manager for deployment using the tools that we focus on in this module, the Azure portal, Azure CLI, and Azure PowerShell. Once the ARM template is deployed, it affects the changes defined inside the ARM template in Azure, changes such as creating the resources, edit existing resources or their properties or even deleting resources. When it comes to creating ARM templates, you can build and export an ARM template from the Azure portal or you can write your own manually. Additionally, you can start from the Quickstart library, which is a collection of community templates available in the Azure portal in the Custom deployment blade.

When you deploy an ARM template, Resource Manager receives that template, formatted as JSON, and then converts the template into REST API operations. This means that you can use many different tools to deploy your ARM templates, including the Azure portal, Azure CLI, Azure PowerShell with the Az module, REST API endpoints directly, and, of course, Azure Cloud Shell.

### ARM templates:
* JSON file that defines your resources
* Building block for automation
* Templates are submitted to ARM for provisioning
* Export a ARM Template in Azure Portal
* Write your own
* Deploy from the Quickstart template library

### Deploying ARM Templates:
* Azure Portal
* Azure CLI
* PowerShell (Az Module)
* REST API
* Azure Cloud Shell

### ARM Template Format
```powershell
{
"$schema": "https://schema.management.azure.com/schemas/2019-04-01/.
deploymentTemplate.json#",
"contentVersion": "",
"apiProfile": "",
"parameters": { },
"variables": { },
"functions": [ ],
"resources": [ ],
"outputs": { }
}
```

[Structure and syntax of ARM templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/syntax)

* **$schema** - Location of the JSON schema file that describes the version of the template language.
* **contentVersion** - Version of the template (such as 1.0.0.0). You can provide any value for this element. Use this value to document significant changes in your template.
* **apiProfile** - An API version that serves as a collection of API versions for resource types. Use this value to avoid having to specify API versions for each resource in the template.
* **parameters** - Values that are provided when deployment is executed to customize resource deployment.
* **variables** - Values that are used as JSON fragments in the template to simplify template language expressions.
* **functions** - User-defined functions that are available within the template.
* **resources** - Resource types that are deployed or updated in a resource group or subscription.
* **outputs** - Values that are returned after deployment.

##### Demo:
To create ARM template we can download it in Azure Portal instead of Create resource. Then we can download template, add to library or deploy to Azure.
![](images/vm-create-arm-template.png)

Schema:
```json
"$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
```

ContentVersion:
```json
"contentVersion": "1.0.0.0",
```


Parameters:
```json
"parameters": {
        "location": {
            "type": "string"
        },
        "networkInterfaceName": {
            "type": "string"
        },
        "networkSecurityGroupName": {
            "type": "string"
        }
        #...
    }
```

Variables:
```json
"variables": {
        "nsgId": "[resourceId(resourceGroup().name, 'Microsoft.Network/networkSecurityGroups', parameters('networkSecurityGroupName'))]",
        "vnetId": "[resourceId(resourceGroup().name,'Microsoft.Network/virtualNetworks', parameters('virtualNetworkName'))]",
        "subnetRef": "[concat(variables('vnetId'), '/subnets/', parameters('subnetName'))]"
    }
```

Resources:
```json
"resources": [
        {
            "name": "[parameters('networkInterfaceName')]",
            "type": "Microsoft.Network/networkInterfaces",
            #...
        },
        {
            "name": "[parameters('networkSecurityGroupName')]",
            "type": "Microsoft.Network/networkSecurityGroups",
            #...
        },
        {
            "name": "[parameters('virtualNetworkName')]",
            "type": "Microsoft.Network/virtualNetworks",
            #...
        },
        {
            "name": "[parameters('publicIpAddressName')]",
            "type": "Microsoft.Network/publicIpAddresses",
            #...
        },
        {
            "name": "[parameters('virtualMachineName')]",
            "type": "Microsoft.Compute/virtualMachines",
            "apiVersion": "2020-06-01",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[concat('Microsoft.Network/networkInterfaces/', parameters('networkInterfaceName'))]"
            ],
            "properties": {
                #...
            }
        }
    ]
```

Outputs:
```json
"outputs": {
        "adminUsername": {
            "type": "string",
            "value": "[parameters('adminUsername')]"
        }
    }
```

##### Deploying ARM Template:
```powershell
#Let's login, may launch a browser to authenticate the session.
Connect-AzAccount -SubscriptionName 'Demonstration Account'


#Ensure you're pointed at your correct subscription
Set-AzContext -SubscriptionName 'Demonstration Account'


#If you resources already exist, you can use this to remove the resource group
Remove-AzResourceGroup -Name 'psdemo-rg'


#Recreate the Resource Group
New-AzResourceGroup -Name 'psdemo-rg' -Location 'CentralUS'


#We can deploy ARM Templates using the Portal, Azure CLI or PowerShell
#Make sure to set the adminPassword parameter in parameters.json prior to deployment.
#Once finished, look for ProvisioningState Succeeded.
New-AzResourceGroupDeployment `
    -Name mydeployment -ResourceGroupName 'psdemo-rg' `
    -TemplateFile './template/template.json' `
    -TemplateParameterFile './template/parameters.json'