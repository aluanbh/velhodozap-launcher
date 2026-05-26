🗺️ Roadmap de Desenvolvimento: VelhoDoZap
Fase 1: Configuração Nativa e Permissões (O Alicerce)
Antes de desenhar a tela, precisamos garantir que o Flutter consiga conversar com o Android para abrir o WhatsApp/YouTube do jeito que você quer e se comportar como a tela inicial.

Configurar o Launcher: Alterar o AndroidManifest.xml para responder ao botão Home.

Queries de Pacotes: Adicionar permissões no manifesto para que o app consiga "enxergar" se o WhatsApp e o YouTube estão instalados no aparelho.

Permissões de Sistema: Configurar permissões para ler o estado da bateria, Wi-Fi e realizar chamadas telefônicas diretas.

Fase 2: A Barra de Status Gigante (Top Bar)
O Android nativo esconde essas informações ou as deixa muito pequenas. Vamos criar nossa própria barra no topo da tela.

Bateria: Utilizar o pacote battery_plus para monitorar a porcentagem e o estado de carregamento em tempo real.

Conectividade (Wi-Fi/Sinal): Utilizar o pacote connectivity_plus para saber se está no Wi-Fi ou dados móveis. (Nota: Para o nível exato do sinal de rede celular em dbm, o Flutter exige código nativo Kotlin/MethodChannel, então no MVP comece mostrando apenas se está "Conectado à Rede Móvel" ou "Wi-Fi").

Bluetooth: Utilizar o pacote flutter_blue_plus apenas para escutar se o Bluetooth está ativo/inativo.

Fase 3: A Interface Principal (Grid de Botões Gigantes)
A usabilidade aqui manda: use Card ou Container com cantos arredondados, fontes grandes (fontSize: 24 para cima) e cores com alto contraste.

Botão Telefone: Configurar para abrir a tela interna de contatos criadas por você.

Botão WhatsApp: Usar o pacote external_app_launcher ou url_launcher. Para garantir que o WhatsApp "resete" ou volte para a tela de chats (comportamento padrão do Android quando reaberto pelo launcher), configuramos a flag nativa de inicialização.

Botão YouTube: Mesma lógica do WhatsApp. Se o app já estiver aberto em um vídeo em segundo plano, ao clicar no launcher, ele força a reabertura da Home do YouTube.

Botão Configurações Discreto: Um IconButton pequeno em um dos cantos inferiores (ou acionado por um clique longo em algum lugar) para evitar que ele mude as configurações sem querer.

Fase 4: Tela de Contatos Principais (A joia da coroa)
Uma segunda tela simples com uma lista (ou Grid de 4 fotos grandes).

Fotos de Contato: Como você quer as fotos do WhatsApp, o ideal no MVP é você salvar as fotos manualmente na pasta assets/ do projeto (ex: vovo.png, filho.png) associadas ao número deles. Puxar a foto direto do perfil do WhatsApp de forma automática e dinâmica quebra com facilidade devido às diretrizes de privacidade do próprio WhatsApp.

Ação de Ligar: Usar o pacote url_launcher com o schema tel:+55... para chamadas normais.

Ação de Ligar via WhatsApp: Usar o link de API do WhatsApp (whatsapp://send?phone=... ou [https://wa.me/](https://wa.me/)...). Isso abrirá diretamente a conversa com o contato.

🛠️ Código Técnico: Primeiros Passos Práticos
Para você já colocar a mão na massa no seu projeto Flutter, aqui está a configuração inicial do Android:

1. Transformando o app em Launcher
Abra o arquivo android/app/src/main/AndroidManifest.xml. Dentro da tag <activity> principal (a que tem o .MainActivity), adicione as categorias de HOME dentro do <intent-filter> existente, ou crie um novo bloco abaixo do principal:

XML
<intent-filter>
    <action android:name="android.intent.action.MAIN"/>
    <category android:name="android.intent.category.HOME"/>
    <category android:name="android.intent.category.DEFAULT"/>
</intent-filter>
2. Permitindo que o Flutter veja o WhatsApp e YouTube
A partir das versões mais novas do Android, um app não consegue ver os outros a menos que você declare explicitamente. Ainda no AndroidManifest.xml, mas fora da tag <application> (no mesmo nível de hierarquia), adicione:

XML
<queries>
    <!-- WhatsApp -->
    <package android:name="com.whatsapp" />
    <!-- YouTube -->
    <package android:name="com.google.android.youtube" />
</queries>

<!-- Permissão para fazer ligações diretas se necessário -->
<uses-permission android:name="android.permission.CALL_PHONE" />
3. Lógica para abrir os Apps no Flutter (Exemplo prático)
No seu pubspec.yaml, adicione o pacote para gerenciar a abertura de apps externos:

YAML
dependencies:
  flutter:
    sdk: flutter
  external_app_launcher: ^3.1.0
  url_launcher: ^6.3.0
No seu código Flutter, para criar as funções dos botões do WhatsApp e YouTube com o comportamento de reabertura limpa que você pediu:

Dart
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

class LauncherController {
  
  // Abrir o WhatsApp
  static Future<void> abrirWhatsApp() async {
    await LaunchApp.openApp(
      androidPackageName: 'com.whatsapp',
      openStore: false, // Não abre a Play Store se não tiver
    );
  }

  // Abrir o YouTube
  static Future<void> abrirYouTube() async {
    await LaunchApp.openApp(
      androidPackageName: 'com.google.android.youtube',
      openStore: false,
    );
  }

  // Ligar para contato (Discagem Direta)
  static Future<void> ligarTelefoneNormal(String numero) async {
    final Uri url = Uri.parse('tel:$numero');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // Abrir conversa direta no WhatsApp do contato
  static Future<void> abrirConversaWhatsApp(String numero) async {
    // O número precisa estar no formato internacional: 5538999999999
    final Uri url = Uri.parse('whatsapp://send?phone=$numero');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
Próximo passo sugerido:
Comece criando o layout da tela principal com a sua barra de status personalizada no topo e um GridView ocupando o restante da tela para os 4 botões principais.

O design dessa tela com os tamanhos ideais e componentes de Grid, ou a lógica reativa da bateria.