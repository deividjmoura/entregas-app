# Instruções — Scripts do Backlog (Parte 3)

## Arquivos

| Arquivo | O que faz |
|---------|-----------|
| `05-foto.sh` | Busca e mostra a foto do item (sob demanda) |
| `06-chat.sh` | Tela de chat por solicitação |
| `07-presenca.sh` | Contador de entregadores online (opcional) |

---

## Como usar

```bash
cd ~/entregas_app

# Extraia o zip do backlog para a pasta scripts/
unzip ~/Downloads/entregas-app-backlog.zip -d .

chmod +x scripts/05-foto.sh scripts/06-chat.sh scripts/07-presenca.sh

# Rode na ordem (ou só os que quiser)
./scripts/05-foto.sh
./scripts/06-chat.sh
./scripts/07-presenca.sh   # opcional

# Se usou o 07:
flutter pub add uuid

flutter pub get
flutter run
```

---

## Observações

### 05 — Foto
- Cria `lib/widgets/foto_item.dart`
- Adiciona `SolicitacaoService.buscarFoto()`
- Para mostrar na tela de detalhe, use:
  ```dart
  if (item.temFoto) ...[
    const SizedBox(height: 16),
    FotoItem(solicitacaoId: item.id),
  ]
  ```

### 06 — Chat
- Cria `lib/screens/chat_screen.dart`
- Atualiza o model `Mensagem`
- Chat só funciona quando status é `EM_CURSO`, `EM_ROTA` ou `EM_BAIXA`
- Para abrir:
  ```dart
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(solicitacao: item),
    ),
  );
  ```

### 07 — Presença
- Opcional e de baixa prioridade
- Precisa do pacote `uuid` (`flutter pub add uuid`)
- Envia heartbeat a cada ~20s e mostra quantos estão online

---

## Ordem completa de todos os scripts

```
01-firebase-auth.sh
02-acoes-solicitacao.sh
03-cores-status-e-realtime.sh
05-foto.sh          ← backlog
06-chat.sh          ← backlog
07-presenca.sh      ← backlog (opcional)
```
