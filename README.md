<div align="center">

# 📦 Entregas App

**App Flutter para entregadores e solicitantes — consome a Central de Despacho em tempo real.**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Pusher](https://img.shields.io/badge/Pusher-300D4F?style=for-the-badge&logo=pusher&logoColor=white)](https://pusher.com)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)

[![GitHub last commit](https://img.shields.io/github/last-commit/deividjmoura/entregas-app?style=flat-square)](https://github.com/deividjmoura/entregas-app/commits/main)
[![GitHub repo size](https://img.shields.io/github/repo-size/deividjmoura/entregas-app?style=flat-square)](https://github.com/deividjmoura/entregas-app)
[![GitHub top language](https://img.shields.io/github/languages/top/deividjmoura/entregas-app?style=flat-square)](https://github.com/deividjmoura/entregas-app)
[![GitHub stars](https://img.shields.io/github/stars/deividjmoura/entregas-app?style=flat-square)](https://github.com/deividjmoura/entregas-app/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/deividjmoura/entregas-app?style=flat-square)](https://github.com/deividjmoura/entregas-app/issues)

**[🌐 Backend / API (entregas-teste)](https://github.com/deividjmoura/entregas-teste)** · **[🔗 Demo web](https://entregas-teste.vercel.app)**

</div>

---

## 📌 Sobre o projeto

O **entregas-app** é o cliente mobile (Flutter) da **Central de Despacho**, consumindo o backend Next.js do projeto [`entregas-teste`](https://github.com/deividjmoura/entregas-teste). Foi desenvolvido como app nativo separado — não como conversão do painel web — para dar aos entregadores uma experiência otimizada, com fila em tempo real via Pusher e armazenamento seguro de credenciais.

## ✨ Funcionalidades

| Módulo | Descrição |
|---|---|
| 🔐 **Login por código de acesso** | Autenticação via token, salvo com segurança (`flutter_secure_storage`) |
| 🚴 **Fila do entregador** | Lista de solicitações em tempo real via Pusher, com favoritar, alterar status e cancelar |
| 🧭 **Menu lateral (Drawer)** | Navegação organizada, espelhando a estrutura do painel web |
| 📋 **Painel do solicitante** | Favoritar e refazer pedidos, com os mesmos dados do backend |
| ⚡ **Atualização automática** | Polling a cada 5s + pull-to-refresh, sem necessidade de botão manual |
| 🖼️ **Visualização de fotos** | Acesso rápido às imagens das solicitações |

### 🔮 Ainda não implementado

- Chat entre solicitante e entregador (via Firebase)
- Presença de usuários online (`sessionId`)
- Autenticação Firebase (`signInAnonymously` + `updateProfile`)
- Ícone e nome personalizados do app
- Build final assinado para distribuição (`flutter build apk --release`)

## 🛠️ Stack técnica

- **Framework**: Flutter
- **HTTP**: pacote `http`, consumindo a API REST do `entregas-teste`
- **Armazenamento seguro**: `flutter_secure_storage`
- **Tempo real**: `pusher_channels_flutter` (canal `painel-entregas`, evento `nova-entrega`)
- **Autenticação/Chat (planejado)**: `firebase_core` + `firebase_auth`
- **Plataformas suportadas**: Android, Web (Chrome), Linux Desktop

## 🔑 Decisões de arquitetura

- **App separado, não conversão**: o Flutter não é um "clone" do Next.js — é um cliente próprio, otimizado para mobile.
- **Auth via token estático Bearer**: sem JWT dinâmico; o backend valida o token em cada requisição.
- **Lógica de negócio centralizada no backend**: o app consome a fila e dados sensíveis via API REST, sem regras de negócio duplicadas no cliente.
- **Chat e presença via Firebase direto** (quando implementados), enquanto a **fila em tempo real usa Pusher** — não polling puro no mobile.

## 🚀 Como rodar localmente

```bash
git clone https://github.com/deividjmoura/entregas-app.git
cd entregas-app

flutter pub get
flutter run
```

> **Linux Desktop**: requer `libsecret-1-dev` instalado para o keyring do `flutter_secure_storage`.
>
> **Android**: compileSdk/targetSdk 36 — se o build falhar no `aapt2`, force `android.aapt2FromMavenOverride` em `android/gradle.properties` apontando para o `aapt2` mais recente instalado.
>
> **Web (Chrome)**: adicione o SDK JS do Pusher (`https://js.pusher.com/8.2.0/pusher.min.js`) em `web/index.html`.

## 📁 Estrutura do projeto

```
entregas_app/
├── lib/
│   ├── screens/       # Telas (login, fila, home)
│   ├── services/       # API client, serviço de solicitações, Pusher
│   └── models/          # Modelos de dados (ex: Solicitacao)
├── android/ ios/ linux/ macos/ windows/ web/   # Plataformas suportadas
└── test/               # Testes
```

## 🔗 Projetos relacionados

Este app consome a API do **[entregas-teste](https://github.com/deividjmoura/entregas-teste)** (Next.js + Prisma), que também serve o painel web em produção.

## 🗺️ Roadmap

Veja o roadmap detalhado em [`ROADMAP.md`](./ROADMAP.md).

## 📄 Licença

Projeto privado/demo — sem licença pública definida.