# Script de Publicação Automática de Aplicativos e Componentes WinForms (Inova)
# Este script verifica quais projetos tiveram alteração manual de versão em seu AssemblyInfo.cs,
# compila em modo Release usando o MSBuild correspondente e envia os pacotes atualizados (.zip e .dll) para o GitHub.

$ErrorActionPreference = "Stop"

# Configurações do Repositório de Releases
$repoUrl = "https://github.com/In9vaExpress/inova-win-releases.git"
$releasesPath = Join-Path $PSScriptRoot "..\inova-win-releases" # c:\InovaTI\CODIGO\inova-win-releases

# Lista dos Componentes a serem Rastreados
$components = @(
    @{
        Name = "Model"
        Type = "Dll"
        ProjectFolder = "Inova-Windows\Model"
        Csproj = "Inova-Windows\Model\Model.csproj"
        AssemblyInfo = "Inova-Windows\Model\Properties\AssemblyInfo.cs"
        OutputFile = "Model.dll"
        ReleaseFile = "Model.dll"
    },
    @{
        Name = "Infra"
        Type = "Dll"
        ProjectFolder = "Inova-Windows\Infra"
        Csproj = "Inova-Windows\Infra\Infra.csproj"
        AssemblyInfo = "Inova-Windows\Infra\Properties\AssemblyInfo.cs"
        OutputFile = "Infra.dll"
        ReleaseFile = "Infra.dll"
    },
    @{
        Name = "InovaDF"
        Type = "Dll"
        ProjectFolder = "Inova-Windows\InovaDF"
        Csproj = "Inova-Windows\InovaDF\InovaDF.csproj"
        AssemblyInfo = "Inova-Windows\InovaDF\Properties\AssemblyInfo.cs"
        OutputFile = "InovaDF.dll"
        ReleaseFile = "InovaDF.dll"
    },
    @{
        Name = "INOVADF_NFe"
        Type = "Dll"
        ProjectFolder = "Inova-Windows\InovaDF_NFe"
        Csproj = "Inova-Windows\InovaDF_NFe\InovaDF_NFe.csproj"
        AssemblyInfo = "Inova-Windows\InovaDF_NFe\Properties\AssemblyInfo.cs"
        OutputFile = "InovaDF_NFe.dll"
        ReleaseFile = "INOVADF_NFe.dll"
    },
    @{
        Name = "NFCe"
        Type = "App"
        ProjectFolder = "Inova-Windows\NFCe"
        Csproj = "Inova-Windows\NFCe\NFCe.csproj"
        AssemblyInfo = "Inova-Windows\NFCe\Properties\AssemblyInfo.cs"
        OutputFile = "NFCe.exe"
        ReleaseFile = "NFCe.zip"
    },
    @{
        Name = "Gerenciador"
        Type = "App"
        ProjectFolder = "Inova-Windows\Gerenciador"
        Csproj = "Inova-Windows\Gerenciador\Gerenciador.csproj"
        AssemblyInfo = "Inova-Windows\Gerenciador\Properties\AssemblyInfo.cs"
        OutputFile = "Gerenciador.exe"
        ReleaseFile = "Gerenciador.zip"
    }
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   INICIANDO PUBLICAÇÃO DOS APLICATIVOS WINFORMS E DLLS" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Garantir que o repositório de releases esteja clonado e atualizado
if (-not (Test-Path $releasesPath)) {
    Write-Host "[1/5] Clonando repositório de releases no GitHub..." -ForegroundColor Yellow
    git clone $repoUrl $releasesPath
} else {
    Write-Host "[1/5] Sincronizando repositório de releases local..." -ForegroundColor Yellow
    Push-Location $releasesPath
    git checkout main
    git pull
    Pop-Location
}

# 2. Carregar manifesto local de atualizações do repositório de releases
$manifestPath = Join-Path $releasesPath "manifest.json"
$manifest = @{}
if (Test-Path $manifestPath) {
    try {
        $manifestJson = Get-Content $manifestPath -Raw
        $manifest = ConvertFrom-Json $manifestJson -AsHashtable
    } catch {
        Write-Host "Erro ao ler o manifest.json atual. Um novo manifesto será criado." -ForegroundColor Yellow
    }
}

# 3. Detectar mudanças de versão em cada componente
Write-Host "`n[2/5] Analisando versões nos arquivos AssemblyInfo.cs..." -ForegroundColor Yellow
$componentsToPublish = @()

foreach ($comp in $components) {
    $assemblyInfoPath = Join-Path $PSScriptRoot $comp.AssemblyInfo
    if (-not (Test-Path $assemblyInfoPath)) {
        Write-Host "Aviso: Arquivo de versão não encontrado para $($comp.Name) ($assemblyInfoPath)" -ForegroundColor Red
        continue
    }

    $content = Get-Content $assemblyInfoPath -Raw
    $localVersion = ""
    # Busca a versão no AssemblyFileVersion ou AssemblyVersion
    if ($content -match '\[assembly:\s*AssemblyVersion\(\s*"([^"]+)"\s*\)\]') {
        $localVersion = $Matches[1]
    }

    if ([string]::IsNullOrEmpty($localVersion)) {
        Write-Host "Aviso: Não foi possível extrair a versão de $($comp.Name)" -ForegroundColor Red
        continue
    }

    # Busca a versão lançada no manifesto
    $releasedVersion = ""
    if ($manifest.ContainsKey($comp.Name)) {
        $releasedVersion = $manifest[$comp.Name].Version
    }

    Write-Host "Componente: $($comp.Name.PadRight(15)) | Versão Local: $localVersion | Versão no GitHub: $($releasedVersion -or 'Nenhum')" -ForegroundColor White

    if ($localVersion -ne $releasedVersion) {
        $comp["NewVersion"] = $localVersion
        $componentsToPublish += $comp
    }
}

if ($componentsToPublish.Count -eq 0) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "   NENHUMA ALTERAÇÃO DE VERSÃO DETECTADA. NADA A PUBLICAR." -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    exit 0
}

# Incrementa a versão do pacote
$versionFilePath = Join-Path $PSScriptRoot "version.txt"
$currentVersion = "1.01"
if (Test-Path $versionFilePath) {
    $currentVersion = (Get-Content $versionFilePath).Trim()
}

function Increment-Version($version) {
    if ($version -match '^(\d+)\.(\d+)$') {
        $major = [int]$Matches[1]
        $minorStr = $Matches[2]
        $minor = [int]$minorStr
        $minor++
        if ($minorStr.Length -eq 2 -and $minor -lt 10) {
            return "$major.0$minor"
        }
        return "$major.$minor"
    }
    return "1.01"
}

$newVersion = Increment-Version $currentVersion
Write-Host "Incrementando a versão do pacote de $currentVersion para $newVersion..." -ForegroundColor Cyan
Set-Content -Path $versionFilePath -Value $newVersion

Write-Host "`n[3/5] Identificados $($componentsToPublish.Count) componentes para compilar e atualizar:" -ForegroundColor Green
foreach ($comp in $componentsToPublish) {
    Write-Host " - $($comp.Name) (Versão: $($comp.NewVersion))" -ForegroundColor Green
}

# 4. Encontrar MSBuild do Visual Studio dinamicamente
$vswherePath = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
$msbuildPath = ""
if (Test-Path $vswherePath) {
    $msbuildPath = & $vswherePath -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe
}
if ([string]::IsNullOrEmpty($msbuildPath)) {
    $msbuildPath = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
}

if (-not (Test-Path $msbuildPath)) {
    Write-Error "Erro: Não foi possível localizar o MSBuild.exe na máquina local."
}
Write-Host "Usando MSBuild: $msbuildPath" -ForegroundColor Gray

# 5. Compilar, empacotar e atualizar arquivos
Write-Host "`n[4/5] Iniciando compilação e empacotamento..." -ForegroundColor Yellow

$updatedListStr = @()

foreach ($comp in $componentsToPublish) {
    Write-Host "`n----------------------------------------------------------" -ForegroundColor Gray
    Write-Host " Compilando $($comp.Name) v$($comp.NewVersion)..." -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------" -ForegroundColor Gray

    $csprojPath = Join-Path $PSScriptRoot $comp.Csproj
    
    # 5.1 Restaurar dependências
    Write-Host "Restaurando NuGet do projeto $($comp.Name)..." -ForegroundColor Gray
    
    $nugetExe = Join-Path $PSScriptRoot "nuget.exe"
    if (-not (Test-Path $nugetExe)) {
        Write-Host "Baixando nuget.exe..." -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetExe
    }

    & $nugetExe restore $csprojPath -SolutionDirectory "$PSScriptRoot\Inova-Windows" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "nuget.exe falhou, tentando msbuild restore..." -ForegroundColor Yellow
        & $msbuildPath $csprojPath /t:Restore /p:Configuration=Release | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Erro: A restauração de dependências para $($comp.Name) falhou."
        }
    }
    
    # 5.2 Compilar em modo Release
    Write-Host "Compilando $($comp.Name) em modo Release..." -ForegroundColor Gray
    & $msbuildPath $csprojPath /t:Build /p:Configuration=Release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Erro: A compilação de $($comp.Name) falhou."
    }

    # 5.3 Empacotar
    if ($comp.Type -eq "App") {
        # Criar pasta de staging limpa para compactação
        $stagingDir = Join-Path $PSScriptRoot "Staging_$($comp.Name)"
        if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force }
        New-Item -ItemType Directory -Path $stagingDir | Out-Null

        Get-ChildItem -Path $binPath -File | Copy-Item -Destination $stagingDir -Force

        # Compilar e incluir o Launcher correspondente no pacote staging
        Write-Host "Compilando Launcher para $($comp.Name)..." -ForegroundColor Cyan
        $launcherCsproj = Join-Path $PSScriptRoot "Inova-Windows\Inova.Launcher\Inova.Launcher.csproj"
        $launcherName = "Start" + $comp.Name
        $launcherIcon = Join-Path $PSScriptRoot "$($comp.ProjectFolder)\app.ico"
        $launcherOutDir = Join-Path $PSScriptRoot "Inova-Windows\Inova.Launcher\bin\Release_$($comp.Name)"

        # Restaura NuGet do Launcher
        & $nugetExe restore $launcherCsproj -SolutionDirectory "$PSScriptRoot\Inova-Windows" | Out-Null

        # Compila Launcher via MSBuild com propriedades dinâmicas
        & $msbuildPath $launcherCsproj /t:Rebuild /p:Configuration=Release /p:AssemblyName=$launcherName /p:ApplicationIcon=$launcherIcon /p:OutputPath=$launcherOutDir
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Erro: A compilação do Launcher para $($comp.Name) falhou."
        }

        # Copia executável e DLLs resultantes para a pasta de staging
        Get-ChildItem -Path $launcherOutDir -File | Where-Object { $_.Extension -eq ".exe" -or $_.Extension -eq ".dll" } | Copy-Item -Destination $stagingDir -Force

        # Remover debug/sujeiras, arquivos .config e de configurações locais para não sobrescrever dados dos clientes
        Get-ChildItem -Path $stagingDir -Filter "*.pdb" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $stagingDir -Filter "*.xml" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $stagingDir -Filter "*.config" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $stagingDir -Filter "ConfigNFCe.json" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $stagingDir -Filter "ConfigGerenciador.json" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $stagingDir -Filter "ConfigNFCe.ini" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $stagingDir -Filter "ConfigGerenciador.ini" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue

        # Comparar com pasta base de instalação para reduzir tamanho do zip (excluir arquivos idênticos)
        $baseInstallFolder = Join-Path $PSScriptRoot "BaseInstallation\$($comp.Name)"
        if (Test-Path $baseInstallFolder) {
            Write-Host "Comparando arquivos com a instalação base em $baseInstallFolder..." -ForegroundColor Cyan
            $files = Get-ChildItem -Path $stagingDir -File -Recurse
            $removedCount = 0
            foreach ($file in $files) {
                # Obter caminho relativo
                $relPath = $file.FullName.Substring($stagingDir.Length).TrimStart("\")
                $baseFile = Join-Path $baseInstallFolder $relPath
                if (Test-Path $baseFile) {
                    $baseFileInfo = Get-Item $baseFile
                    if ($file.Length -eq $baseFileInfo.Length) {
                        $hash1 = (Get-FileHash -Path $file.FullName -Algorithm MD5).Hash
                        $hash2 = (Get-FileHash -Path $baseFile -Algorithm MD5).Hash
                        if ($hash1 -eq $hash2) {
                            Remove-Item $file.FullName -Force
                            $removedCount++
                        }
                    }
                }
            }
            # Remover subdiretórios que ficaram vazios
            Get-ChildItem -Path $stagingDir -Directory -Recurse | 
                Sort-Object -Property FullName -Descending | 
                Where-Object { (Get-ChildItem -Path $_.FullName -Recurse) -eq $null } | 
                Remove-Item -Force

            Write-Host "Excluídos $removedCount arquivo(s) idêntico(s) à base de instalação do pacote." -ForegroundColor Gray
        } else {
            Write-Host "Aviso: Pasta base de instalação não encontrada em $baseInstallFolder. Subindo pacote completo." -ForegroundColor Yellow
        }

        # Gerar o arquivo .zip final
        $zipDest = Join-Path $releasesPath $comp.ReleaseFile
        if (Test-Path $zipDest) { Remove-Item $zipDest -Force }
        Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipDest -Force

        # Remover pasta de staging temporária
        Remove-Item $stagingDir -Recurse -Force
        Write-Host "Aplicativo $($comp.Name) compactado com sucesso em $($comp.ReleaseFile)." -ForegroundColor Green
    } else {
        # Copiar DLL diretamente
        $dllSource = Join-Path $PSScriptRoot "$($comp.ProjectFolder)\bin\Release\$($comp.OutputFile)"
        $dllDest = Join-Path $releasesPath $comp.ReleaseFile
        Copy-Item -Path $dllSource -Destination $dllDest -Force
        Write-Host "DLL $($comp.Name) copiada com sucesso para $($comp.ReleaseFile)." -ForegroundColor Green
    }

    # 5.5 Atualizar objeto do manifesto
    $manifest[$comp.Name] = @{
        Version = $comp.NewVersion
        Filename = $comp.ReleaseFile
    }

    $updatedListStr += "$($comp.Name) v$($comp.NewVersion)"
}

# Salvar a versão do pacote no manifesto
$manifest["PackageVersion"] = $newVersion

# Salva o novo manifest.json no repositório de releases
$newManifestJson = ConvertTo-Json $manifest -Depth 5
Set-Content -Path $manifestPath -Value $newManifestJson

# Função para Sincronizar com o Banco de Dados da API Server via HTTP
function Update-ApiServerSettings($columnName, $versionValue) {
    $apiServerUrls = @(
        "http://localhost:5020",
        "https://api.in9vaexpress.com.br"
    )
    $apiKey = "InovaSecretToken2026"
    
    $body = @{}
    $body[$columnName] = $versionValue
    $jsonBody = ConvertTo-Json $body

    $headers = @{
        "X-Api-Key" = $apiKey
        "Content-Type" = "application/json"
    }

    foreach ($url in $apiServerUrls) {
        $endpoint = "$url/v1/Settings/update-version"
        try {
            Write-Host "Atualizando versão no servidor $endpoint..." -ForegroundColor Yellow
            $response = Invoke-RestMethod -Uri $endpoint -Method Put -Headers $headers -Body $jsonBody -TimeoutSec 3
            Write-Host "Sucesso ao atualizar $endpoint!" -ForegroundColor Green
        } catch {
            Write-Host "Falha ao atualizar $($endpoint) - $_" -ForegroundColor Red
        }
    }
}

# 6. Sincronizar alterações com o GitHub (Incremental Push rápido por padrão)
Write-Host "`n[5/5] Enviando atualizações para o GitHub..." -ForegroundColor Yellow
Push-Location $releasesPath

# Configuração de usuário para o git
git config user.email "tiao.tj2@gmail.com"
git config user.name "tiao"

$commitMsg = "release: atualização dos componentes (" + ($updatedListStr -join ", ") + ") para pacote v$newVersion"

if ($env:CLEAN_HISTORY -eq "true") {
    Write-Host "Limpando histórico do Git e executando push forçado..." -ForegroundColor Cyan
    git checkout --orphan temp_branch
    git add -A
    git commit -m $commitMsg
    git branch -M temp_branch main
    git push origin main --force

    # Adicionar tag e subir para o GitHub
    Write-Host "Criando e enviando tag v$newVersion..." -ForegroundColor Yellow
    if (git tag -l "v$newVersion") {
        git tag -d "v$newVersion"
    }
    git tag "v$newVersion"
    git push origin "v$newVersion" --force

    git reflog expire --expire=now --all
    git gc --prune=now
} else {
    Write-Host "Executando push incremental rápido..." -ForegroundColor Cyan
    git checkout main
    git add -A
    git commit -m $commitMsg
    git push origin main

    # Adicionar tag e subir para o GitHub
    Write-Host "Criando e enviando tag v$newVersion..." -ForegroundColor Yellow
    if (git tag -l "v$newVersion") {
        git tag -d "v$newVersion"
    }
    git tag "v$newVersion"
    git push origin "v$newVersion" --force
}

Pop-Location

# Atualiza a API Server apenas após todo o envio com sucesso
Update-ApiServerSettings -columnName "versaoInovaWindow" -versionValue $newVersion

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   TODAS AS ATUALIZAÇÕES FORAM PUBLICADAS COM SUCESSO!" -ForegroundColor Green
Write-Host "   PACOTE VERSÃO: v$newVersion" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
