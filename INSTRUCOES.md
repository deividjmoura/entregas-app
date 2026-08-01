# Instruções de uso — Scripts entregas-app

## Arquivos gerados

| Arquivo | O que faz |
|---------|-----------|
| `01-firebase-auth.sh` | Identidade do entregador (Firebase + Google + Login) |
| `02-acoes-solicitacao.sh` | Ações corretas (`/assumir`, `/confirmar`, status + endereço) |
| `03-cores-status-e-realtime.sh` | Cores oficiais, labels, polling 5s e sessão persistente |

---

## Como usar (copie e cole)

### 1. Baixe os scripts para a pasta do projeto

```bash
cd ~/entregas_app
mkdir -p scripts
```

Coloque os 3 arquivos `.sh` dentro da pasta `scripts/`.

### 2. Dê permissão de execução

```bash
chmod +x scripts/*.sh
```

### 3. Configure o Firebase (só na primeira vez)

```bash
flutterfire configure
```

Escolha o **mesmo projeto Firebase** que o `entregas-teste` usa.

### 4. Rode os scripts na ordem

```bash
./scripts/01-firebase-auth.sh
./scripts/02-acoes-solicitacao.sh
./scripts/03-cores-status-e-realtime.sh
```

### 5. Limpe e rode o app

```bash
flutter clean
flutter pub get
flutter run
```

---

## Ordem obrigatória

1. **01** → Identidade (Firebase + Login)
2. **02** → Ações de solicitação
3. **03** → Cores + Polling + Sessão

Não pule etapas.

---

## O que cada script corrige

### 01 — Firebase Auth
- Inicializa Firebase
- Login com Google ou Visitante
- AuthGate (sessão persiste)
- Nome do entregador disponível para as ações

### 02 — Ações corretas
- `assumir` manda `entregadorNome` e trata 409
- Status só `EM_ROTA` / `EM_BAIXA`
- `confirmar` usa a rota correta
- Botões contextuais na tela de detalhe
- Edição de endereço de estoque

### 03 — Visual e tempo real
- Cores de urgência iguais ao web
- Labels de status e tipo
- Polling a cada 5 segundos
- Sessão persistente

---

## Problemas comuns

| Erro | Solução |
|------|---------|
| `firebase_options.dart` não encontrado | Rode `flutterfire configure` antes |
| Gradle / Java incompatível | Use Java 17: `flutter config --jdk-dir=/usr/lib/jvm/java-17-openjdk-amd64` |
| Token inválido | Confirme que o `ACCESS_TOKEN` do backend é o mesmo usado no app |

---

## Próximos (backlog – peça se precisar)

- `05-foto.sh` → visualizar foto do item
- `06-chat.sh` → chat da entrega
- `07-presenca.sh` → contador de entregadores online
