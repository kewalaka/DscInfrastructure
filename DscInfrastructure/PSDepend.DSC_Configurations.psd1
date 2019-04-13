@{
    PSDependOptions = @{
        AddToPath      = $true
        Target         = 'DSC_Configurations'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    CommonTasks        = 'latest'
    SQLServerDscConfig = '0.0.1.0'
}
