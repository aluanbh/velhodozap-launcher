O real motivo da falha
Nas versões mais recentes do Android, o WhatsApp não aceita que você simplesmente passe a string 5538999999999@s.whatsapp.net na Intent e mande ligar.

Para disparar uma chamada de voz ou vídeo via ACTION_VIEW, você é obrigado a consultar o banco de dados nativo de contatos do Android, encontrar a linha exata que relaciona aquele número ao "MimeType" de chamada do WhatsApp e, então, pegar o _ID dessa linha para montar a URI (ex: content://com.android.contacts/data/12345).

Como você já criou o MethodChannel('velhodozap/platform_intents'), a solução é implementar a busca desse _ID no lado nativo (Kotlin).

A Solução: MainActivity.kt
Abra o arquivo nativo do seu projeto em android/app/src/main/kotlin/com/example/velhodozap/MainActivity.kt e substitua (ou integre) com o código abaixo.

Ele faz exatamente o que o Android exige: varre a tabela nativa de contatos atrás do MimeType de voz ou vídeo do WhatsApp para aquele número específico e dispara a Intent com o ID correto.

Kotlin
package com.example.velhodozap

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "velhodozap/platform_intents"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startWhatsAppCall" -> {
                    val phoneRaw = call.argument<String>("phoneRaw") ?: ""
                    val isVideo = call.argument<Boolean>("isVideo") ?: false
                    
                    val success = makeWhatsAppCall(phoneRaw, isVideo)
                    result.success(success)
                }
                "openWhatsAppChat" -> {
                    val phoneRaw = call.argument<String>("phoneRaw") ?: ""
                    val success = openWhatsAppChat(phoneRaw)
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun makeWhatsAppCall(phoneRaw: String, isVideo: Boolean): Boolean {
        // Limpa o número deixando apenas dígitos
        val digits = phoneRaw.replace(Regex("\\D"), "")
        // Garante o DDI (55 para Brasil)
        val e164 = if (digits.startsWith("55")) digits else "55$digits"
        val jid = "$e164@s.whatsapp.net"

        val mimeType = if (isVideo) {
            "vnd.android.cursor.item/vnd.com.whatsapp.video.call"
        } else {
            "vnd.android.cursor.item/vnd.com.whatsapp.voip.call"
        }

        val resolver = contentResolver
        val projection = arrayOf(ContactsContract.Data._ID)
        // Busca na tabela de contatos onde o MimeType é do WhatsApp E o número de registro bate
        val selection = "${ContactsContract.Data.MIMETYPE} = ? AND ${ContactsContract.Data.DATA1} = ?"
        val selectionArgs = arrayOf(mimeType, jid)

        var cursor: Cursor? = null
        try {
            cursor = resolver.query(
                ContactsContract.Data.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )

            if (cursor != null && cursor.moveToFirst()) {
                // Pega o ID nativo daquele contato no banco do Android
                val idIndex = cursor.getColumnIndexOrThrow(ContactsContract.Data._ID)
                val id = cursor.getLong(idIndex)
                
                // Monta a URI exata exigida pelo WhatsApp
                val uri = Uri.parse("content://com.android.contacts/data/$id")
                
                val intent = Intent(Intent.ACTION_VIEW)
                intent.setDataAndType(uri, mimeType)
                intent.setPackage("com.whatsapp")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                
                startActivity(intent)
                return true // Sucesso, vai retornar true para o Dart
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            cursor?.close()
        }
        
        return false // Falhou (contato não existe na agenda ou não tem WhatsApp)
    }

    private fun openWhatsAppChat(phoneRaw: String): Boolean {
        return try {
            val digits = phoneRaw.replace(Regex("\\D"), "")
            val e164 = if (digits.startsWith("55")) digits else "55$digits"
            val jid = "$e164@s.whatsapp.net"
            
            val intent = Intent(Intent.ACTION_VIEW)
            intent.setDataAndType(Uri.parse("content://com.android.contacts/data/$jid"), "vnd.android.cursor.item/vnd.com.whatsapp.profile")
            intent.setPackage("com.whatsapp")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
Dois detalhes importantes:
Sincronização é obrigatória: Como vimos na resposta anterior, para esse código Kotlin achar o ID no banco, o WhatsApp precisa estar sincronizado com a agenda do Android. Se o contato for novo e o WhatsApp não rodou a sincronização de contatos, a busca nativa retorna null e a ligação falha (caindo no seu fallback inteligente do Dart de abrir o chat).

Permissão Nativa: Garanta que você colocou a permissão de ler contatos no AndroidManifest.xml, caso contrário a query do Kotlin vai crashar silenciosamente:
<uses-permission android:name="android.permission.READ_CONTACTS" />

Atualizando o Kotlin, as funções do seu painel devem disparar a chamada instantaneamente no aparelho da Xiaomi! Teste aí e me avise.