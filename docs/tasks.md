Tarefas (baseadas no seu roadmap + requisitos “simples e prático”)

- Transformar o app em launcher (AndroidManifest: intent-filter HOME/DEFAULT).
- Declarar <queries> e permissões no AndroidManifest (WhatsApp/YouTube, CALL_PHONE se necessário).
- Adicionar dependências no pubspec ( battery_plus , connectivity_plus , flutter_blue_plus , url_launcher e/ou external_app_launcher ).
- Criar layout da Home: barra de status grande no topo + grid de botões grandes (Telefone, WhatsApp, YouTube) + botão discreto de Configurações.
- Implementar barra de status: bateria (percentual/charging) via battery_plus .
- Implementar barra de status: conectividade (Wi‑Fi vs dados móveis) via connectivity_plus + exibir “tipo do sinal” em texto grande (MVP).
- Implementar barra de status: Bluetooth ligado/desligado via flutter_blue_plus .
- Implementar exibição “qualidade do sinal” (decisão: MVP só texto genérico; avançado via Kotlin/MethodChannel para nível de sinal real).
- Criar tela “Contatos principais”: lista/grid com 4+ contatos, nome e foto grande (assets), ação “Ligar” ( tel: ).
- Adicionar ação “WhatsApp do contato”: abrir conversa via wa.me / whatsapp://send?phone=... (formato internacional).
- Implementar botão Telefone na Home: navegar para tela de contatos principais.
- Implementar botão WhatsApp na Home: abrir WhatsApp direto na tela de chats (usar Intent/flags via plugin ou MethodChannel se necessário).
- Implementar botão YouTube na Home: relançar YouTube (quando já aberto, forçar “fechar e abrir”/nova tarefa).
- Implementar botão discreto de Configurações: abrir configurações do app (ou do sistema) com proteção contra toque acidental.
- Ajustar acessibilidade/legibilidade: fontes grandes (>=24), alto contraste, áreas de toque grandes.
- Testar em dispositivo Android: launcher padrão, abertura WhatsApp/YouTube, chamadas, permissões e atualizações em tempo real da barra.