#az Login
#Azure CLI commands used during CLI portion of the demos

#Assessment
#Execuete the following CLI statement to run an assessment against your source SQL Server Instance you are migrating the databases from.
az datamigration get-assessment --connection-string "Data Source={your source SQL Server database instance};Initial Catalog=Master;Integrated Security=True" --output-folder "C:\Output" --overwrite

#SKU Reccomendation 
#Execute the following CLI to assess your source SQL Server Instance you are migrating the databases from.
#Be sure to execute against a representitve sample to obtain the best recommended SKU ( This is in Preview )
az datamigration performance-data-collection --connection-string "Data Source={your source SQL Server database instance};Initial Catalog=master;Integrated Security=True" `
--output-folder "C:\Output" --perf-query-interval 10 --static-query-interval 120

#Then to build the SKU reccomendation report
#Execute against the following to create the JSON assessment report. Executed on the Jumpbox we placed the output results to. 
az datamigration get-sku-recommendation --output-folder "C:\Output" --display-result --overwrite --target-platform AzureSQLManagedInstance


#Build the DMS
#Execute the following against your Azure Subscription
az account set --subscription "{your subscription name that you are deploying Database Migration Service to}"
az datamigration sql-service create --resource-group "{resource group you want to deploy DM to" --sql-migration-service-name "{Database Migration Service Name}" --location "EastUS"


#Deploy MIgration to MI
#Recall each DB being migrated requires it own container for its full, differential, and log backups 
#Creates a variable for your subscription ID so that it is not passed in as clear text
#Creates a variable for your storage account access keys so that it is not passed in as clear text
#Starts the online migration to Managed Instance
$SUB_ID = (az account show --query id)  -replace '"'
$KEY_ID = (az storage account keys list -g {resource group containing you storage account} -n {storage account name containg DB backups} --query "[0].value")  -replace '"'
$SOURCELOC = '{\"AzureBlob\":{\"storageAccountResourceId\":\"/subscriptions/' + $SUB_ID + '/resourceGroups/{resource group containing you storage account}/providers/Microsoft.Storage/storageAccounts/{storage account name containg DB backups}\",\"accountKey\":\"' +$KEY_ID+ '\",\"blobContainerName\":\"{storage account container with DB backup\"}}'


az datamigration sql-managed-instance create `
--source-location $SOURCELOC `
--migration-service "/subscriptions/$SUB_ID/resourceGroups/{resource group that your deployed the DMS to}/providers/Microsoft.DataMigration/SqlMigrationServices/{DMS name that you deployed earlier}" `
--scope "/subscriptions/$SUB_ID/resourceGroups/{resource group that contains the MI migrating to}/providers/Microsoft.Sql/managedInstances/{MI being migrating to}" `
--source-database-name "{Source DB name}" `
--target-db-name "{Target DB Name}" `
--resource-group /{resource group that contains the MI migrating to} `
--managed-instance-name {MI being migrating to} 


#show full details of the provisions state
az datamigration sql-managed-instance show --managed-instance-name "{MI being migrating to}" --resource-group "{resource group that contains the MI migrating to}" --target-db-name "{Target DB Name}" `
--expand=MigrationStatusDetails

#Check providioning state of the online migration
#Provisioning State should be Creating, Failed or Succeeded
az datamigration sql-managed-instance show --managed-instance-name "{MI being migrating to}" --resource-group "{resource group that contains the MI migrating to}" --target-db-name "{Target DB Name}" `
--expand=MigrationStatusDetails --query "properties.provisioningState"

#Check migration status of the online migration
# MigrationStatus should be InProgress, Canceling, Failed or Succeeded
az datamigration sql-managed-instance show --managed-instance-name "{MI being migrating to}" --resource-group "{resource group that contains the MI migrating to}" --target-db-name "{Target DB Name}" `
--expand=MigrationStatusDetails --query "properties.migrationStatus"

#Cutover the online migration 
#Command prompt will display when cutover is complete
#Recall that in Business Critcal this will take longer as we are seeding 3 replicas of the database
$migOpId = az datamigration sql-managed-instance show --managed-instance-name "{MI being migrating to}" --resource-group "{resource group that contains the MI migrating to}" `
--target-db-name "{Target DB Name}" --expand=MigrationStatusDetails --query "properties.migrationOperationId"
az datamigration sql-managed-instance cutover --managed-instance-name "{MI being migrating to}" --resource-group "{resource group that contains the MI migrating to}" --target-db-name "{Target DB Name}" --migration-operation-id $migOpId

#T-SQL Scripts I executed during the Demo
