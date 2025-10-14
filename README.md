# FusionInventory Agent Installer

Este repositório contém um script de **batch** para automatizar a instalação do **FusionInventory Agent** em máquinas Windows. O script foi reorganizado em funções para facilitar a manutenção e passou a validar permissões administrativas, controlar ações opcionais (firewall e RDP), identificar corretamente a arquitetura do sistema (inclusive em ambientes WOW64), verificar se o serviço já está rodando, instalar o agente quando necessário e configurar o serviço para iniciar automaticamente com políticas de recuperação.

## Funcionalidades

- Desabilita o Firewall do Windows (opcional e configurável).
- Configura o serviço de Área de Trabalho Remota (RDP) (opcional e configurável).
- Valida se o **FusionInventory Agent** já está instalado.
- Baixa e instala a versão correta do agente conforme a arquitetura do sistema (x86 ou x64).
- Reinicia o serviço do agente e força o inventário após a instalação.
- Configura o serviço do agente para iniciar automaticamente com atraso e para reiniciar em caso de falhas.
- Verifica o status do agente após a instalação e informa eventuais falhas.

## Pré-requisitos

- A máquina deve ter acesso ao servidor FusionInventory configurado no script (por padrão `127.0.0.1`).
- Ferramentas como `bitsadmin`, `curl` ou `PowerShell` devem estar disponíveis no sistema operacional.
- Acesso de administrador para modificar as configurações de firewall e serviços.

## Como usar

1. **Clone o repositório**:

   ```bash
   git clone git@github.com:OrlanRocha/Batch-FusionInventory-GLPI.git
   cd fusioninventory-agent-installer
   ```

2. **Ajuste as configurações conforme a sua infraestrutura** (opcional):

   No início do arquivo `fusioninventory.bat` existem variáveis que controlam o IP do servidor GLPI, o caminho do plugin, a versão do agente, o tempo de espera para finalização da instalação e as ações opcionais de firewall/RDP. Ajuste-as conforme necessário antes de executar o script.

3. **Execute o script em um prompt elevado**:

   Abra o Prompt de Comando como **Administrador** e execute:

   ```bat
   fusioninventory.bat
   ```
