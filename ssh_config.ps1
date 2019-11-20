$GLOBAL_SUBSCRIPTION_NAME = ""

class ConfigItem {
  <#
  .DESCRIPTION
    This class is for holding data about an SSH File Config Entry

    According to the official documentation (https://www.ssh.com/ssh/config/)

    An entry in SSH Config File, may hold following information

    * Host
    * HostName
    * User
    * Port
    * Compression
  #>
  [string]$Host
  [string]$HostName
  [string]$User
  [string]$Port
  [string]$Compression
}

function DisplayLogo {
  <#
  .DESCRIPTION
    Displays "CSE SSH Helper" Ascii-Art logo on screen
  #>
Write-Host @"
   ___________ ______   __________ __  __   __  __     __               
  / ____/ ___// ____/  / ___/ ___// / / /  / / / /__  / /___  ___  _____
 / /    \__ \/ __/     \__ \\__ \/ /_/ /  / /_/ / _ \/ / __ \/ _ \/ ___/
/ /___ ___/ / /___    ___/ /__/ / __  /  / __  /  __/ / /_/ /  __/ /    
\____//____/_____/   /____/____/_/ /_/  /_/ /_/\___/_/ .___/\___/_/     
                                                    /_/                 
"@;
}

function DisplayMenu {
  <#
  .DESCRIPTION
    Displays menu items on screen
  #>

  # Display logo on top
  DisplayLogo;

  $ANSWER = $null
  while ($ANSWER -ne 'q')
  {
    Write-Host '0. Login Azure'
    Write-Host '1. List VM Machines'
    Write-Host '2. Start VM Machine(s)'
    Write-Host '3. Stop VM Machine(s)'
    Write-Host '4. Clean SSH Config File'
    Write-Host '5. Add SSH Config for Azure VMs'
    Write-Host '6. Help'
    Write-Host '7. Quit (q)'
    $ANSWER = Read-Host 'Please select an option'
    switch ($ANSWER)
    {
        '0' { LoginAzure; }
        '1' { DisplayVMList; }
        '2' { StartVM; }
        '3' { StopVM; }
        '4' { CleanSSHConfigFile; }
        '5' { AddSSHConfig; }
        '6' { DisplayHelp; }
        '7' { exit }
        'q' { exit }
        default { Write-Host 'Input not understood, try again'; }
    }
  }
}

function LoginAzure {
  <#
  .DESCRIPTION
    Checks and if it's needed, logins user to the Azure Portal using Azure CLI (az)
  #>

  # CHECK IF USER IS LOGGED IN TO AZ CLI
  $LOGGED_IN = az account list --output tsv

  # IF NOT, LOGIN FIRST
  if ($LOGGED_IN -eq 0) {
    az login
  }

  # LIST SUBSCRIPTIONS
  $LIST = az account list --query "[].name" --output json | ConvertFrom-Json

  # ASK USER WHICH SUBSCRIPTION WILL BE USED AFTERWARDS
  $SELECTION = Write-Menu -Title 'Which subscription you want to use?' -Entries $LIST

  # STORE SUBSCRIPTION_NAME FOR FUTURE REFERENCES
  $GLOBAL_SUBSCRIPTION_NAME = $SELECTION

  Write-Host "Your selection is '$SELECTION'"

  # CHANGE DEFAULT SUBSCRIPTION TO SELECTED ONE
  az account set --subscription $SELECTION

  Write-Host "Default subscription selection changed to '$SELECTION'"
}

function DisplayVMList {
  $VM_LIST = az vm list --show-details --query "[].{Name:name, PowerState:powerState}" --output json | ConvertFrom-Json

  Write-Host ""

  foreach ($VM in $VM_LIST) {
    Write-Host $VM.Name ":" $VM.PowerState
  }

  Write-Host ""
}

function StartVM {
  $LIST = az vm list --show-details --query "[].{Name:name, PowerState:powerState, ResourceGroup:resourceGroup}" --output json | ConvertFrom-Json

  $SELECTION = Write-Menu -Title 'Which VMs do you want to start?' -MultiSelect -Entries ($LIST | ForEach-Object { $_.Name })

  # ITERATE OVER TARGET VMS
  foreach ($VM_NAME in $SELECTION) {
    $ITEM = $LIST.Where({ $_.Name -eq $VM_NAME });

    az vm start --name "$($ITEM.Name)" --resource-group "$($ITEM.ResourceGroup)"
  }
}

function StopVM {
  $LIST = az vm list --show-details --query "[].{Name:name, PowerState:powerState, ResourceGroup:resourceGroup}" --output json | ConvertFrom-Json

  $SELECTION = Write-Menu -Title 'Which VMs do you want to stop?' -MultiSelect -Entries ($LIST | ForEach-Object { $_.Name })

  # ITERATE OVER TARGET VMS
  foreach ($VM_NAME in $SELECTION) {
    $ITEM = $LIST.Where({ $_.Name -eq $VM_NAME });

    az vm stop --name "$($ITEM.Name)" --resource-group "$($ITEM.ResourceGroup)"
  }
}

function CleanSSHConfigFile {
  <#
  .DESCRIPTION
    Cleans selected un-used SSH Config entries from SSH Config File
  #>
  $SSH_CONFIG_FILE_CONTENT = "";

  $SSH_CONFIG_PATH = "C:\\Users\\$env:UserName\\.ssh\\config";

  $FILE_CONTENT = Get-Content $SSH_CONFIG_PATH

  $CONFIG_ITEM_LIST = @();

  $CURRENT_ITEM_INDEX = -1;

  $iLoop = 0;

  for ($iLoop -eq 0; $iLoop -lt ($FILE_CONTENT.Length-1); $iLoop++) {
    $LINE = $FILE_CONTENT[$iLoop];

    if ($LINE.Trim().StartsWith("Host ")) {
      $CURRENT_ITEM_INDEX++;

      $ITEM = @([ConfigItem]@{ Host=$LINE.Replace("Host", "").Trim() });

      $CONFIG_ITEM_LIST += $ITEM;
    } elseif ($LINE.Trim().StartsWith("HostName ")) {
      $ITEM = $CONFIG_ITEM_LIST[$CURRENT_ITEM_INDEX];

      $ITEM.HostName = $LINE.Replace("HostName", "").Trim()
    } elseif ($LINE.Trim().StartsWith("User ")) {
      $ITEM = $CONFIG_ITEM_LIST[$CURRENT_ITEM_INDEX];

      $ITEM.User = $LINE.Replace("User", "").Trim()
    } elseif ($LINE.Trim().StartsWith("Port ")) {
      $ITEM = $CONFIG_ITEM_LIST[$CURRENT_ITEM_INDEX];

      $ITEM.Port = $LINE.Replace("Port", "").Trim()
    } elseif ($LINE.Trim().StartsWith("Compression ")) {
      $ITEM = $CONFIG_ITEM_LIST[$CURRENT_ITEM_INDEX];

      $ITEM.Compression = $LINE.Replace("Compression", "").Trim()
    }
  }

  if ($CONFIG_ITEM_LIST.Count -eq 0) {
    Read-Host "SSH Config file is empty... Continue?"
    return;
  }

  $SELECTION = Write-Menu -Title 'Which config entries do you want to keep?' -MultiSelect -Entries ($CONFIG_ITEM_LIST | ForEach-Object { "$($_.Host) ($($_.HostName))" });

  $NEW_CONFIG_CONTENT = "";

  foreach ($ITEM in $CONFIG_ITEM_LIST) {
    $FOUND = $false;

    foreach ($SUB_ITEM in $SELECTION) {
      if ($ITEM.Host.Trim() -eq $SUB_ITEM.SubString(0, $SUB_ITEM.IndexOf("(")).Trim()) {
        $FOUND = $true;

        break;
      }
    }

    if ($FOUND) {
      $NEW_CONFIG_CONTENT += "Host $($ITEM.Host)`n";
      if ($ITEM.HostName -ne "") {
        $NEW_CONFIG_CONTENT += "  HostName $($ITEM.HostName)`n"
      }
      if ($ITEM.User -ne "") {
        $NEW_CONFIG_CONTENT += "  User $($ITEM.User)`n"
      }
      if ($ITEM.Port -ne "") {
        $NEW_CONFIG_CONTENT += "  Port $($ITEM.Port)`n"
      }
      if ($ITEM.Compression -ne "") {
        $NEW_CONFIG_CONTENT += "  Compression $($ITEM.Compression)`n"
      }
      $NEW_CONFIG_CONTENT += "`n"
    }
  }

  Set-Content $SSH_CONFIG_PATH $NEW_CONFIG_CONTENT
}

function AddSSHConfig {
  <#
  .DESCRIPTION
    Creates SSH Config entries for selected VMs of the Azure Subscription
  #>
  $SSH_CONFIG_PATH = "C:\\Users\\$env:UserName\\.ssh\\config";

  $LIST = az vm list --show-details --output json | ConvertFrom-Json;

  if ($LIST.Count -eq 0) {
    Write-Host "There is no VM in $GLOBAL_SUBSCRIPTION_NAME subscription, please check if you have access to required Resource Groups..."
    Read-Host
    return;
  } else {
    $PROJECT_NAME = Read-Host "If you want to have prefixes for the VMs (Project Name, Customer Name, etc.), please enter"

    if ($PROJECT_NAME -ne "") {
      $PROJECT_NAME = $PROJECT_NAME + "-"
    }

    $SELECTION = Write-Menu -Title 'Which VMs do you want add to your SSH Config file?' -MultiSelect -Entries ($LIST | ForEach-Object { $_.Name });

    $CONFIG_CONTENT = "";
    # ITERATE OVER TARGET VMS
    foreach ($VM_NAME in $SELECTION) {
      $ITEM = $LIST.Where({ $_.name -eq $VM_NAME });

      $HOSTNAME = $ITEM.fqdns;
      if ($HOSTNAME -eq "") {
        $HOSTNAME = $ITEM.publicIps;
      }

      if ($HOSTNAME -eq "") {
        Write-Host "There is no way to connect to $($ITEM.name) , it has no FQDNS, no Public Ip Address. It may not started. Skipping..."
      } else {
        $USER = Read-Host "What is SSH User for $($ITEM.name)";
        $USER_CONTENT = "";
        if ($USER -ne "") {
          $USER_CONTENT = "  User $USER`n"
        }

        $CONFIG_CONTENT += "Host $($PROJECT_NAME)$($ITEM.name)`n  HostName $($HOSTNAME)`n$USER_CONTENT`n";
      }
    }

    Add-Content $SSH_CONFIG_PATH $CONFIG_CONTENT
  }
}

function DisplayHelp {
  <#
  .DESCRIPTION
    Displays help on screen
  #>
  Write-Host ""
  Write-Host "Login Azure"
  Write-Host "-----------"
  Write-Host "Checks if you already logged-in to Azure CLI"
  Write-Host "If you are not logged-in yet, display Login Page of Azure Portal"
  Write-Host "After successfull login, it displays all subscriptions you have"
  Write-Host "So, you can choose a subscription"
  Write-Host "Afterwards, all the command will be executed on this subscription"
  Write-Host ""

  Write-Host "List VM Machines"
  Write-Host "-----------"
  Write-Host "Gets VM list from current Azure Subscription"
  Write-Host "Display list on the screen"
  Write-Host ""

  Write-Host "Start VM Machine(s)"
  Write-Host "-----------"
  Write-Host "Gets VM list from current Azure Subscription"
  Write-Host "Display list on the screen with checkboxes"
  Write-Host "Checked VMs in the list will be started"
  Write-Host ""

  Write-Host "Stop VM Machine(s)"
  Write-Host "-----------"
  Write-Host "Gets VM list from current Azure Subscription"
  Write-Host "Display list on the screen with checkboxes"
  Write-Host "Checked VMs in the list will be stopped"
  Write-Host ""

  Write-Host "Clean SSH Config File"
  Write-Host "-----------"
  Write-Host "Lists the configuration in SSH Config file"
  Write-Host "Checked configuration stays in the file"
  Write-Host "UnChecked configuration will be removed from file"
  Write-Host ""

  Write-Host "Add SSH Config for Azure VMs"
  Write-Host "-----------"
  Write-Host "Lists the VMs in Azure Subscription"
  Write-Host "Add configuration in SSH Config file for checked VMs"
  Write-Host ""

  Read-Host "Continue?"
}

<#
    The MIT License (MIT)

    Copyright (c) 2016 QuietusPlus

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>
function Write-Menu {
    <#
        .SYNOPSIS
            Outputs a command-line menu which can be navigated using the keyboard.

        .DESCRIPTION
            Outputs a command-line menu which can be navigated using the keyboard.

            * Automatically creates multiple pages if the entries cannot fit on-screen.
            * Supports nested menus using a combination of hashtables and arrays.
            * No entry / page limitations (apart from device performance).
            * Sort entries using the -Sort parameter.
            * -MultiSelect: Use space to check a selected entry, all checked entries will be invoked / returned upon confirmation.
            * Jump to the top / bottom of the page using the "Home" and "End" keys.
            * "Scrolling" list effect by automatically switching pages when reaching the top/bottom.
            * Nested menu indicator next to entries.
            * Remembers parent menus: Opening three levels of nested menus means you have to press "Esc" three times.

            Controls             Description
            --------             -----------
            Up                   Previous entry
            Down                 Next entry
            Left / PageUp        Previous page
            Right / PageDown     Next page
            Home                 Jump to top
            End                  Jump to bottom
            Space                Check selection (-MultiSelect only)
            Enter                Confirm selection
            Esc / Backspace      Exit / Previous menu

        .EXAMPLE
            PS C:\>$menuReturn = Write-Menu -Title 'Menu Title' -Entries @('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')

            Output:

              Menu Title

               Menu Option 1
               Menu Option 2
               Menu Option 3
               Menu Option 4

        .EXAMPLE
            PS C:\>$menuReturn = Write-Menu -Title 'AppxPackages' -Entries (Get-AppxPackage).Name -Sort

            This example uses Write-Menu to sort and list app packages (Windows Store/Modern Apps) that are installed for the current profile.

        .EXAMPLE
            PS C:\>$menuReturn = Write-Menu -Title 'Advanced Menu' -Sort -Entries @{
                'Command Entry' = '(Get-AppxPackage).Name'
                'Invoke Entry' = '@(Get-AppxPackage).Name'
                'Hashtable Entry' = @{
                    'Array Entry' = "@('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')"
                }
            }

            This example includes all possible entry types:

            Command Entry     Invoke without opening as nested menu (does not contain any prefixes)
            Invoke Entry      Invoke and open as nested menu (contains the "@" prefix)
            Hashtable Entry   Opened as a nested menu
            Array Entry       Opened as a nested menu

        .NOTES
            Write-Menu by QuietusPlus (inspired by "Simple Textbased Powershell Menu" [Michael Albert])

        .LINK
            https://quietusplus.github.io/Write-Menu

        .LINK
            https://github.com/QuietusPlus/Write-Menu
    #>

    [CmdletBinding()]

    <#
        Parameters
    #>

    param(
        # Array or hashtable containing the menu entries
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('InputObject')]
        $Entries,

        # Title shown at the top of the menu.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]
        $Title,

        # Sort entries before they are displayed.
        [Parameter()]
        [switch]
        $Sort,

        # Select multiple menu entries using space, each selected entry will then get invoked (this will disable nested menu's).
        [Parameter()]
        [switch]
        $MultiSelect
    )

    <#
        Configuration
    #>

    # Entry prefix, suffix and padding
    $script:cfgPrefix = ' '
    $script:cfgPadding = 2
    $script:cfgSuffix = ' '
    $script:cfgNested = ' >'

    # Minimum page width
    $script:cfgWidth = 30

    # Hide cursor
    [System.Console]::CursorVisible = $false

    # Save initial colours
    $script:colorForeground = [System.Console]::ForegroundColor
    $script:colorBackground = [System.Console]::BackgroundColor

    <#
        Checks
    #>

    # Check if entries has been passed
    if ($Entries -like $null) {
        Write-Error "Missing -Entries parameter!"
        return
    }

    # Check if host is console
    if ($host.Name -ne 'ConsoleHost') {
        Write-Error "[$($host.Name)] Cannot run inside current host, please use a console window instead!"
        return
    }

    <#
        Set-Color
    #>

    function Set-Color ([switch]$Inverted) {
        switch ($Inverted) {
            $true {
                [System.Console]::ForegroundColor = $colorBackground
                [System.Console]::BackgroundColor = $colorForeground
            }
            Default {
                [System.Console]::ForegroundColor = $colorForeground
                [System.Console]::BackgroundColor = $colorBackground
            }
        }
    }

    <#
        Get-Menu
    #>

    function Get-Menu ($script:inputEntries) {
        # Clear console
        Clear-Host

        # Check if -Title has been provided, if so set window title, otherwise set default.
        if ($Title -notlike $null) {
            $host.UI.RawUI.WindowTitle = $Title
            $script:menuTitle = "$Title"
        } else {
            $script:menuTitle = 'Menu'
        }

        # Set menu height
        $script:pageSize = ($host.UI.RawUI.WindowSize.Height - 5)

        # Convert entries to object
        $script:menuEntries = @()
        switch ($inputEntries.GetType().Name) {
            'String' {
                # Set total entries
                $script:menuEntryTotal = 1
                # Create object
                $script:menuEntries = New-Object PSObject -Property @{
                    Command = ''
                    Name = $inputEntries
                    Selected = $false
                    onConfirm = 'Name'
                }; break
            }
            'Object[]' {
                # Get total entries
                $script:menuEntryTotal = $inputEntries.Length
                # Loop through array
                foreach ($i in 0..$($menuEntryTotal - 1)) {
                    # Create object
                    $script:menuEntries += New-Object PSObject -Property @{
                        Command = ''
                        Name = $($inputEntries)[$i]
                        Selected = $false
                        onConfirm = 'Name'
                    }; $i++
                }; break
            }
            'Hashtable' {
                # Get total entries
                $script:menuEntryTotal = $inputEntries.Count
                # Loop through hashtable
                foreach ($i in 0..($menuEntryTotal - 1)) {
                    # Check if hashtable contains a single entry, copy values directly if true
                    if ($menuEntryTotal -eq 1) {
                        $tempName = $($inputEntries.Keys)
                        $tempCommand = $($inputEntries.Values)
                    } else {
                        $tempName = $($inputEntries.Keys)[$i]
                        $tempCommand = $($inputEntries.Values)[$i]
                    }

                    # Check if command contains nested menu
                    if ($tempCommand.GetType().Name -eq 'Hashtable') {
                        $tempAction = 'Hashtable'
                    } elseif ($tempCommand.Substring(0,1) -eq '@') {
                        $tempAction = 'Invoke'
                    } else {
                        $tempAction = 'Command'
                    }

                    # Create object
                    $script:menuEntries += New-Object PSObject -Property @{
                        Name = $tempName
                        Command = $tempCommand
                        Selected = $false
                        onConfirm = $tempAction
                    }; $i++
                }; break
            }
            Default {
                Write-Error "Type `"$($inputEntries.GetType().Name)`" not supported, please use an array or hashtable."
                exit
            }
        }

        # Sort entries
        if ($Sort -eq $true) {
            $script:menuEntries = $menuEntries | Sort-Object -Property Name
        }

        # Get longest entry
        $script:entryWidth = ($menuEntries.Name | Measure-Object -Maximum -Property Length).Maximum
        # Widen if -MultiSelect is enabled
        if ($MultiSelect) { $script:entryWidth += 4 }
        # Set minimum entry width
        if ($entryWidth -lt $cfgWidth) { $script:entryWidth = $cfgWidth }
        # Set page width
        $script:pageWidth = $cfgPrefix.Length + $cfgPadding + $entryWidth + $cfgPadding + $cfgSuffix.Length

        # Set current + total pages
        $script:pageCurrent = 0
        $script:pageTotal = [math]::Ceiling((($menuEntryTotal - $pageSize) / $pageSize))

        # Insert new line
        [System.Console]::WriteLine("")

        # Save title line location + write title
        $script:lineTitle = [System.Console]::CursorTop
        [System.Console]::WriteLine("  $menuTitle" + "`n")

        # Save first entry line location
        $script:lineTop = [System.Console]::CursorTop
    }

    <#
        Get-Page
    #>

    function Get-Page {
        # Update header if multiple pages
        if ($pageTotal -ne 0) { Update-Header }

        # Clear entries
        for ($i = 0; $i -le $pageSize; $i++) {
            # Overwrite each entry with whitespace
            [System.Console]::WriteLine("".PadRight($pageWidth) + ' ')
        }

        # Move cursor to first entry
        [System.Console]::CursorTop = $lineTop

        # Get index of first entry
        $script:pageEntryFirst = ($pageSize * $pageCurrent)

        # Get amount of entries for last page + fully populated page
        if ($pageCurrent -eq $pageTotal) {
            $script:pageEntryTotal = ($menuEntryTotal - ($pageSize * $pageTotal))
        } else {
            $script:pageEntryTotal = $pageSize
        }

        # Set position within console
        $script:lineSelected = 0

        # Write all page entries
        for ($i = 0; $i -le ($pageEntryTotal - 1); $i++) {
            Write-Entry $i
        }
    }

    <#
        Write-Entry
    #>

    function Write-Entry ([int16]$Index, [switch]$Update) {
        # Check if entry should be highlighted
        switch ($Update) {
            $true { $lineHighlight = $false; break }
            Default { $lineHighlight = ($Index -eq $lineSelected) }
        }

        # Page entry name
        $pageEntry = $menuEntries[($pageEntryFirst + $Index)].Name

        # Prefix checkbox if -MultiSelect is enabled
        if ($MultiSelect) {
            switch ($menuEntries[($pageEntryFirst + $Index)].Selected) {
                $true { $pageEntry = "[X] $pageEntry"; break }
                Default { $pageEntry = "[ ] $pageEntry" }
            }
        }

        # Full width highlight + Nested menu indicator
        switch ($menuEntries[($pageEntryFirst + $Index)].onConfirm -in 'Hashtable', 'Invoke') {
            $true { $pageEntry = "$pageEntry".PadRight($entryWidth) + "$cfgNested"; break }
            Default { $pageEntry = "$pageEntry".PadRight($entryWidth + $cfgNested.Length) }
        }

        # Write new line and add whitespace without inverted colours
        [System.Console]::Write("`r" + $cfgPrefix)
        # Invert colours if selected
        if ($lineHighlight) { Set-Color -Inverted }
        # Write page entry
        [System.Console]::Write("".PadLeft($cfgPadding) + $pageEntry + "".PadRight($cfgPadding))
        # Restore colours if selected
        if ($lineHighlight) { Set-Color }
        # Entry suffix
        [System.Console]::Write($cfgSuffix + "`n")
    }

    <#
        Update-Entry
    #>

    function Update-Entry ([int16]$Index) {
        # Reset current entry
        [System.Console]::CursorTop = ($lineTop + $lineSelected)
        Write-Entry $lineSelected -Update

        # Write updated entry
        $script:lineSelected = $Index
        [System.Console]::CursorTop = ($lineTop + $Index)
        Write-Entry $lineSelected

        # Move cursor to first entry on page
        [System.Console]::CursorTop = $lineTop
    }

    <#
        Update-Header
    #>

    function Update-Header {
        # Set corrected page numbers
        $pCurrent = ($pageCurrent + 1)
        $pTotal = ($pageTotal + 1)

        # Calculate offset
        $pOffset = ($pTotal.ToString()).Length

        # Build string, use offset and padding to right align current page number
        $script:pageNumber = "{0,-$pOffset}{1,0}" -f "$("$pCurrent".PadLeft($pOffset))","/$pTotal"

        # Move cursor to title
        [System.Console]::CursorTop = $lineTitle
        # Move cursor to the right
        [System.Console]::CursorLeft = ($pageWidth - ($pOffset * 2) - 1)
        # Write page indicator
        [System.Console]::WriteLine("$pageNumber")
    }

    <#
        Initialisation
    #>

    # Get menu
    Get-Menu $Entries

    # Get page
    Get-Page

    # Declare hashtable for nested entries
    $menuNested = [ordered]@{}

    <#
        User Input
    #>

    # Loop through user input until valid key has been pressed
    do { $inputLoop = $true

        # Move cursor to first entry and beginning of line
        [System.Console]::CursorTop = $lineTop
        [System.Console]::Write("`r")

        # Get pressed key
        $menuInput = [System.Console]::ReadKey($false)

        # Define selected entry
        $entrySelected = $menuEntries[($pageEntryFirst + $lineSelected)]

        # Check if key has function attached to it
        switch ($menuInput.Key) {
            # Exit / Return
            { $_ -in 'Escape', 'Backspace' } {
                # Return to parent if current menu is nested
                if ($menuNested.Count -ne 0) {
                    $pageCurrent = 0
                    $Title = $($menuNested.GetEnumerator())[$menuNested.Count - 1].Name
                    Get-Menu $($menuNested.GetEnumerator())[$menuNested.Count - 1].Value
                    Get-Page
                    $menuNested.RemoveAt($menuNested.Count - 1) | Out-Null
                # Otherwise exit and return $null
                } else {
                    Clear-Host
                    $inputLoop = $false
                    [System.Console]::CursorVisible = $true
                    return $null
                }; break
            }

            # Next entry
            'DownArrow' {
                if ($lineSelected -lt ($pageEntryTotal - 1)) { # Check if entry isn't last on page
                    Update-Entry ($lineSelected + 1)
                } elseif ($pageCurrent -ne $pageTotal) { # Switch if not on last page
                    $pageCurrent++
                    Get-Page
                }; break
            }

            # Previous entry
            'UpArrow' {
                if ($lineSelected -gt 0) { # Check if entry isn't first on page
                    Update-Entry ($lineSelected - 1)
                } elseif ($pageCurrent -ne 0) { # Switch if not on first page
                    $pageCurrent--
                    Get-Page
                    Update-Entry ($pageEntryTotal - 1)
                }; break
            }

            # Select top entry
            'Home' {
                if ($lineSelected -ne 0) { # Check if top entry isn't already selected
                    Update-Entry 0
                } elseif ($pageCurrent -ne 0) { # Switch if not on first page
                    $pageCurrent--
                    Get-Page
                    Update-Entry ($pageEntryTotal - 1)
                }; break
            }

            # Select bottom entry
            'End' {
                if ($lineSelected -ne ($pageEntryTotal - 1)) { # Check if bottom entry isn't already selected
                    Update-Entry ($pageEntryTotal - 1)
                } elseif ($pageCurrent -ne $pageTotal) { # Switch if not on last page
                    $pageCurrent++
                    Get-Page
                }; break
            }

            # Next page
            { $_ -in 'RightArrow','PageDown' } {
                if ($pageCurrent -lt $pageTotal) { # Check if already on last page
                    $pageCurrent++
                    Get-Page
                }; break
            }

            # Previous page
            { $_ -in 'LeftArrow','PageUp' } { # Check if already on first page
                if ($pageCurrent -gt 0) {
                    $pageCurrent--
                    Get-Page
                }; break
            }

            # Select/check entry if -MultiSelect is enabled
            'Spacebar' {
                if ($MultiSelect) {
                    switch ($entrySelected.Selected) {
                        $true { $entrySelected.Selected = $false }
                        $false { $entrySelected.Selected = $true }
                    }
                    Update-Entry ($lineSelected)
                }; break
            }

            # Select all if -MultiSelect has been enabled
            'Insert' {
                if ($MultiSelect) {
                    $menuEntries | ForEach-Object {
                        $_.Selected = $true
                    }
                    Get-Page
                }; break
            }

            # Select none if -MultiSelect has been enabled
            'Delete' {
                if ($MultiSelect) {
                    $menuEntries | ForEach-Object {
                        $_.Selected = $false
                    }
                    Get-Page
                }; break
            }

            # Confirm selection
            'Enter' {
                # Check if -MultiSelect has been enabled
                if ($MultiSelect) {
                    Clear-Host
                    # Process checked/selected entries
                    $menuEntries | ForEach-Object {
                        # Entry contains command, invoke it
                        if (($_.Selected) -and ($_.Command -notlike $null) -and ($entrySelected.Command.GetType().Name -ne 'Hashtable')) {
                            Invoke-Expression -Command $_.Command
                        # Return name, entry does not contain command
                        } elseif ($_.Selected) {
                            return $_.Name
                        }
                    }
                    # Exit and re-enable cursor
                    $inputLoop = $false
                    [System.Console]::CursorVisible = $true
                    break
                }

                # Use onConfirm to process entry
                switch ($entrySelected.onConfirm) {
                    # Return hashtable as nested menu
                    'Hashtable' {
                        $menuNested.$Title = $inputEntries
                        $Title = $entrySelected.Name
                        Get-Menu $entrySelected.Command
                        Get-Page
                        break
                    }

                    # Invoke attached command and return as nested menu
                    'Invoke' {
                        $menuNested.$Title = $inputEntries
                        $Title = $entrySelected.Name
                        Get-Menu $(Invoke-Expression -Command $entrySelected.Command.Substring(1))
                        Get-Page
                        break
                    }

                    # Invoke attached command and exit
                    'Command' {
                        Clear-Host
                        Invoke-Expression -Command $entrySelected.Command
                        $inputLoop = $false
                        [System.Console]::CursorVisible = $true
                        break
                    }

                    # Return name and exit
                    'Name' {
                        Clear-Host
                        return $entrySelected.Name
                        $inputLoop = $false
                        [System.Console]::CursorVisible = $true
                    }
                }
            }
        }
    } while ($inputLoop)
}

DisplayMenu;
