#Login and set a subscription
Connect-AzAccount -SubscriptionName 'BizSpark'
Set-AzContext -SubscriptionName 'BizSpark'


#Create a Resource Group
New-AzResourceGroup -Name "iaas-demo-rg" -Location "WestEurope"


#Deploy ARM Template
New-AzResourceGroupDeployment `
    -Name mydeployment -ResourceGroupName 'iaas-demo-rg' `
    -TemplateFile './vm-template/template.json' `
    -TemplateParameterFile './vm-template/parameters.json'