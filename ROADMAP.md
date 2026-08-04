# 🗺️ Roadmap — entregas-app (Flutter)

Status do cliente mobile que consome o backend do `entregas-teste`.

---

## ✅ Concluído

- [x] Estrutura inicial do app Flutter, separado do painel web
- [x] `api_client.dart` para consumo da API REST do backend
- [x] Login com código de acesso, token salvo com segurança (`flutter_secure_storage`)
- [x] Resolução de conflito de dependências (`flutter_secure_storage` ^10.3.1 x `pusher_channels_flutter`)
- [x] Fila do entregador (`fila_screen.dart`) com dados em tempo real via Pusher
- [x] Ações da fila: favoritar (estrela), alterar status e cancelar via menu popup
- [x] Correção de `MissingPluginException` do Pusher no Linux Desktop (try/catch, sem derrubar o app)
- [x] Suporte a Flutter Web: CORS resolvido no backend + SDK JS do Pusher no `index.html`
- [x] Painel do solicitante: favoritar e refazer pedido (paridade com a versão web)
- [x] Menu lateral (Drawer) unificado entre fila do entregador e painel do solicitante
- [x] Remoção do botão de atualizar manual (redundante com polling de 5s + pull-to-refresh)
- [x] Build Android corrigido (aapt2 desatualizado x compileSdk 36 — override configurado)
- [x] Testes (`widget_test.dart`) corrigidos e app testado no Android (emulador Pixel 7 API 34)

## 🚧 Em andamento / próximos passos

- [ ] Personalizar ícone e nome do app
- [ ] Gerar build final de release (`flutter build apk --release`)

## 🔮 Planejado

- [ ] **Chat** entre solicitante e entregador, replicando o model `Mensagem` via Firebase
- [ ] **Presença de usuários** (portar `Presenca`/`sessionId` da versão web)
- [ ] **Autenticação Firebase** (`signInAnonymously` + `updateProfile`) para viabilizar chat e presença
- [ ] Publicação em loja (Play Store) ou distribuição interna (APK assinado)
- [ ] Notificações push (alinhado ao roadmap do backend)

## 💡 Ideias em avaliação

- [ ] Suporte a iOS (build e testes)
- [ ] Modo offline / cache local da fila
- [ ] Testes automatizados de widget mais abrangentes

---

> Este roadmap é um documento vivo e reflete o estado atual do projeto. Ajustes de prioridade podem ocorrer conforme o uso real do app.