#
# JSON Files.ps1 - IDM System PowerShell Script for File System integration, specifically for reading JSON Files
#
# Any IDM System PowerShell Script is dot-sourced in a separate PowerShell context, after
# dot-sourcing the IDM Generic PowerShell Script '../Generic.ps1'.
#


#
# System functions
#

function Idm-SystemInfo {
    param (
        # Operations
        [switch] $Connection,
        [switch] $TestConnection,
        [switch] $Configuration,
        # Parameters
        [string] $ConnectionParams
    )

    Log info "-Connection=$Connection -TestConnection=$TestConnection -Configuration=$Configuration -ConnectionParams='$ConnectionParams'"
    
    if ($Connection) {
        @(
            @{
                name = 'paths_spec'
                type = 'textbox'
                label = 'Paths'
                tooltip = "Paths to collect. Separate multiple paths by '|'. Optionally suffix path with ':<n>' to collect 'n' levels deep."
                value = ''
            }
            @{
                name = 'excludes'
                type = 'textbox'
                label = 'Excludes'
                tooltip = "File name patterns to exclude. Separate multiple patterns by '|'. E.g. *\example excludes all folders with the name 'example' and their contents; *\example\* excludes the contents of all folders with the name 'example', not the folder itself."
                value = ''
            }
             @{
                name = 'recursive'
                type = 'checkbox'
                label = 'Recursive'
                value = $true
            }
			@{
                name = 'recursion_depth'
                type = 'textbox'
                label = 'Recursion Depth'
                tooltip = 'Max. depth of recursion'
                value = 1
                hidden = '!recursive'
            }
        )
    }

    if ($TestConnection) {
        $connection_params = ConvertSystemParams $ConnectionParams

        foreach ($path_spec in $connection_params.paths_spec) {
            Get-ChildItem -Force -LiteralPath $path_spec.path >$null
        }
    }

    if ($Configuration) {
    }

    Log info "Done"
}


#
# CRUD functions
#

$ColumnsInfoCache = @{}

function Idm-Dispatcher {
    param (
        # Optional Class/Operation
        [string] $Class,
        [string] $Operation,
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Log info "-Class='$Class' -Operation='$Operation' -GetMeta=$GetMeta -SystemParams='$SystemParams' -FunctionParams='$FunctionParams'"
    $system_params   = ConvertSystemParams $SystemParams
    $function_params = ConvertFrom-Json2 $FunctionParams

    if ($Class -eq '') {
        if ($GetMeta) {
            #
            # Output list of supported operations per table/view (named Class)
            #

            foreach ($path_spec in $system_params.paths_spec) {
                $path_with_backslash = AppendBackslashToPath $path_spec
    
                $gci_args = @{
                    Directory   = $false
                    File		= $true
                    Force       = $true
                    LiteralPath = $path_spec.path
                    Recurse     = $system_params.recursive
                    Depth       = 0
                    ErrorAction = 'SilentlyContinue'
                }
                
                if($system_params.recursive) {
                    $gci_args.Depth = $system_params.recursion_depth
                }
    
                if ($path_spec.depth -ge 0) {
                    $gci_args.Depth = $path_spec.depth
                }
    
                LogIO info 'Get-ChildItem' -In @gci_args -Exclude $system_params.excludes -Properties $function_params.properties
    
                try {
                    # This is to correct error messages, e.g.:
                    #   "Cannot find drive. A drive with the name 'x' does not exist" instead of
                    #   "A parameter cannot be found that matches parameter name 'Directory'".
                    Get-ChildItem -Force -LiteralPath $path_spec.path >$null
                    
                    # For directories, Get-ChildItem returns [System.IO.DirectoryInfo]
                    Get-ChildItem @gci_args | ForEach-Object {
                        foreach ($exclude in $system_params.excludes) {
                            if ($_.FullName -ilike $exclude) { return }
                        }
    
                        $_
                    } | ForEach-Object {
                        [ordered]@{
                            Class = $_.Name.Replace("-", "_")
                            Operation = 'Read'
                            'Source type' = 'JSON'
                            'Primary key' = ''
                            'Supported operations' = 'R'
                            Path = $_.FullName.Substring(0, $_.FullName.length - $_.Name.Length)
                        }
                    } | Sort-Object Class
                }
                catch {
                    Log error "Failed: $_"
                    Write-Error $_
                }
            }
        }
        else {
            # Purposely no-operation.
        }
    }
    else {

        if ($GetMeta) {
           @() # No Configuration Options
        }
        else {
            #
            # Execute function
            #

             #
            # Output list of supported operations per table/view (named Class)
            #
        
            foreach ($path_spec in $system_params.paths_spec) {

                $path_with_backslash = AppendBackslashToPath $path_spec

                $gci_args = @{
                    Directory   = $false
                    File		= $true
                    Force       = $true
                    LiteralPath = $path_spec.path
                    Recurse     = $system_params.recursive
                    Depth       = 0
                    ErrorAction = 'SilentlyContinue'
                }

                if($system_params.recursive) {
                    $gci_args.Depth = $system_params.recursion_depth
                }

                if ($path_spec.depth -ge 0) {
                    $gci_args.Depth = $path_spec.depth
                }

                LogIO info 'Get-ChildItem' -In @gci_args -Exclude $system_params.excludes -Properties $function_params.properties
    
                try {
                    # This is to correct error messages, e.g.:
                    #   "Cannot find drive. A drive with the name 'x' does not exist" instead of
                    #   "A parameter cannot be found that matches parameter name 'Directory'".
                    Get-ChildItem -Force -LiteralPath $path_spec.path >$null
   
                    # For directories, Get-ChildItem returns [System.IO.DirectoryInfo]
                    Get-ChildItem @gci_args | ForEach-Object {
                        foreach ($exclude in $system_params.excludes) {
                            if ($_.FullName -ilike $exclude) { return }
                        }
    
                        $_
                    } | ForEach-Object {
                        
                        Log debug "$($_.FullName)"
                        if($class -eq $_.Name.Replace("-", "_")) 
                        { 
                            Log debug "PROCESS - $($Class) - $($_.Name.Replace("-", "_"))"
                            Flatten-Json -InputObject (Get-Content $_.FullName| ConvertFrom-Json)    
                        }
                        
                    } 
                }
                catch {
                    Log error "Failed: $_"
                    Write-Error $_
                }
            }

        }

    }

    Log info "Done"
}

#
# Helper functions
#

function ConvertSystemParams {
    param (
        [string] $InputParams
    )

    $params = ConvertFrom-Json2 $InputParams

    $params.paths_spec = @(
        $params.paths_spec.Split('|') | ForEach-Object {
            $value = $_
            if ($value.length -eq 0) { return }

            $p = $value.LastIndexOf(':')

            if ($p -le 1 -or ($p -eq 5 -and $value.IndexOf('\\?\') -eq 0)) {
                # No depth specified or part of drive letter
                @{
                    path  = $value
                    depth = -1
                }
            }
            else {
                @{
                    path  = $value.Substring(0, $p)
                    depth = $value.Substring($p + 1)
                }
            }
        }
    )

    $params.excludes = @(
        $params.excludes.Split('|') | ForEach-Object {
            $value = $_
            if ($value.length -eq 0) { return }

            $value
            $value + '\*'    # Probably always wanted
        }
    )

    $params.principal_type = if ($params.principal_type -eq 'NTAccount') { [System.Security.Principal.NTAccount] } else { [System.Security.Principal.SecurityIdentifier] }

    return $params
}


function AppendBackslashToPath {
    param (
        [string] $Path
    )

    if ($Path.length -eq 0 -or $Path.Substring($Path.length - 1) -eq ':') {
        # Do not append backslash, as it would result in an absolute path
        $Path
    }
    elseif ($Path.Substring($Path.length - 1) -eq '\') {
        # Already ends with a backslash
        $Path
    }
    else {
        $Path + '\'
    }
}

function GetItemsWithDepth {
    param (
        [string]$Path,
        [int]$Depth,
        [array]$Excludes
    )

    # Helper function to recursively list items
    function InternalGetItems {
        param (
            [string]$CurrentPath,
            [int]$CurrentDepth,
            [array]$Exclude
        )
		
        if ($CurrentDepth -ge 0) {
            # Attempt to list the current directory's contents
            $test = $CurrentPath
            try {
                Log debug "Reading $($CurrentPath)"
                try { $items = Get-ChildItem -LiteralPath $CurrentPath -Directory -Force -ErrorAction Stop | ForEach-Object { 
                    foreach ($exclude in $Excludes) {
                        if ($_.FullName -ilike $exclude) { return }
                    }
                    $_
                } } catch { 
                    $err = "Failed to access contents of: [$($CurrentPath)] - $_"
                    Log error $err
					throw $err
                } 

                # Output the items from the current directory
                $items

                # If the depth allows, recurse into subdirectories
                if ($CurrentDepth -gt 0) {
                    foreach ($item in $items) {
                        if ($item.PSIsContainer) {
                            InternalGetItems -CurrentPath $item.FullName -CurrentDepth ($CurrentDepth - 1) -Exclude $Exclude
                        }
                    }
                }
            } catch {
                throw $_
            }
        }
    }

    # Start the recursive listing from the initial path and depth
    InternalGetItems -CurrentPath $Path -CurrentDepth $Depth
}

function Flatten-Json {
    param (
        [Parameter(Mandatory = $true)]
        [object]$InputObject,

        [string]$Prefix = ""
    )

    $flatHash = @{}

    foreach ($key in $InputObject.PSObject.Properties.Name) {
        $value = $InputObject.$key
        $fullKey = if ($Prefix) { "$Prefix`_$key" } else { $key }

        if ($value -is [System.Management.Automation.PSObject]) {
            $subObject = Flatten-Json -InputObject $value -Prefix $fullKey
            foreach ($subKey in $subObject.PSObject.Properties.Name) {
                $flatHash[$subKey] = $subObject.$subKey
            }
        }
        elseif ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            $index = 0
            foreach ($item in $value) {
                $indexedKey = "${fullKey}${index}"
                if ($item -is [System.Management.Automation.PSObject]) {
                    $subObject = Flatten-Json -InputObject $item -Prefix $indexedKey
                    foreach ($subKey in $subObject.PSObject.Properties.Name) {
                        $flatHash[$subKey] = $subObject.$subKey
                    }
                } else {
                    $flatHash[$indexedKey] = $item
                }
                $index++
            }
        }
        else {
            $flatHash[$fullKey] = $value
        }
    }

    return [PSCustomObject]$flatHash
}
