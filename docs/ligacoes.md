1. Como Ligar Direto (Sem passar pelo teclado nativo)
Para o botão de telefone disparar a ligação imediatamente, você precisa de uma permissão especial do Android chamada CALL_PHONE (que você já adicionou no manifesto) e usar um pacote que execute a chamada em nível de sistema, ignorando a tela de discagem.

O pacote ideal para isso é o flutter_phone_direct_caller.

Passo a Passo:
Adicione o pacote no pubspec.yaml:

YAML
dependencies:
  flutter_phone_direct_caller: ^2.1.1
No seu código, substitua a função de ligar por esta:

Dart
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

static Future<void> ligarDireto(String numero) async {
  // Remove espaços, traços e parênteses do número antes de discar
  final numeroLimpo = numero.replaceAll(RegExp(r'[^\d+]'), '');

  bool? res = await FlutterPhoneDirectCaller.callNumber(numeroLimpo);

  if (res == false) {
    // Caso falte alguma permissão em tempo de execução, você pode usar o fallback antigo
    print("Não foi possível ligar diretamente");
  }
}
2. Como Fazer Ligação de Voz ou Vídeo Direta no WhatsApp
Para o WhatsApp, em vez de abrir o chat (que usa o link wa.me), nós vamos usar Intents nativas do Android. O WhatsApp possui "portas de entrada" específicas para iniciar chamadas de voz ou vídeo diretamente, sem que o usuário precise clicar em nada dentro do app.

Para disparar essas Intents de forma simples no Flutter, o melhor caminho é usar o pacote android_intent_plus.

Passo a Passo:
Adicione o pacote no pubspec.yaml:

YAML
dependencies:
  android_intent_plus: ^5.0.3
Crie as funções para chamada de Voz e Vídeo. O segredo aqui é passar o número de telefone formatado com o ID do WhatsApp (exemplo: 5538999999999@s.whatsapp.net).

Dart
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class WhatsappCaller {
  
  // Função auxiliar para limpar e formatar o número pro padrão do WhatsApp
  static String _formatarNumero(String numero) {
    // Remove tudo que não for número
    String limpo = numero.replaceAll(RegExp(r'[^\d]'), '');
    // Garante que tem o código do país (55)
    if (!limpo.startsWith('55')) {
      limpo = '55$limpo';
    }
    return '$limpo@s.whatsapp.net';
  }

  // 📞 CHAMADA DE VOZ DIRETA
  static Future<void> iniciarChamadaVoz(String numero) async {
    final jid = _formatarNumero(numero);
    
    final AndroidIntent intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: 'content://com.android.contacts/data/$jid',
      package: 'com.whatsapp',
      type: 'vnd.android.cursor.item/vnd.com.whatsapp.voip.call',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    
    await intent.launch();
  }

  // 📹 CHAMADA DE VÍDEO DIRETA
  static Future<void> iniciarChamadaVideo(String numero) async {
    final jid = _formatarNumero(numero);
    
    final AndroidIntent intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: 'content://com.android.contacts/data/$jid',
      package: 'com.whatsapp',
      type: 'vnd.android.cursor.item/vnd.com.whatsapp.video.call',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    
    await intent.launch();
  }
}
🧠 Como juntar isso na Interface (UX para o seu sogro)
Como ele tem dificuldade com leitura, em vez de abrir um menu de texto perguntando "O que deseja fazer?", o ideal é criar a ação direto no clique do botão do WhatsApp daquela lista.

Ao clicar no botão verde do WhatsApp da Luana, por exemplo, você pode abrir um pequeno modal (um showDialog ou showModalBottomSheet) com dois botões gigantes com ícones claros:

um botão de Telefone Verde (para chamada de voz)

um botão de Câmera de Vídeo Verde (para chamada de vídeo)

Dessa forma, com apenas 2 cliques rápidos e puramente visuais, ele já estará em uma ligação direta com ela, sem passar por nenhuma tela intermediária do sistema ou do próprio WhatsApp!