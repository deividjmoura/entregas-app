# 🚚 Entregas App

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Android-SDK%2036-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android" />
  <img src="https://img.shields.io/badge/Status-Em%20desenvolvimento-orange?style=for-the-badge" alt="Status" />
</p>

<p align="center">
  <strong>App mobile do sistema de entregas internas</strong><br>
  Fila em tempo real • Lock otimista • Chat por solicitação • Notificações
</p>

---

## 📊 Stats do Projeto

| Métrica                    | Valor                          |
|---------------------------|--------------------------------|
| Linguagem principal       | Dart (79.4%)                   |
| Framework                 | Flutter                        |
| Plataformas               | Android / iOS / Web / Desktop  |
| Autenticação              | Firebase Auth + Google Sign-In |
| Backend                   | [entregas-teste](https://github.com/deividjmoura/entregas-teste) |
| Versão atual              | `1.0.0+1`                      |
| Commits                   | 20+                            |

---

## ✨ Funcionalidades

- [x] Login com **Google** ou como **Visitante**
- [x] Sessão persistente (AuthGate)
- [x] Fila de solicitações ordenada por urgência
- [x] Lock otimista ao assumir entrega (evita conflito)
- [x] Atualização de status (`EM_CURSO` → `EM_ROTA` → `EM_BAIXA` → `ENTREGUE`)
- [x] Cores oficiais e labels de status/urgência
- [x] Polling automático + sincronização visual
- [x] Chat por solicitação
- [x] Visualização de foto do item
- [x] Notificações locais
- [x] Edição de endereço no estoque

---

## 🛠️ Stack Tecnológica

| Tecnologia                    | Uso                              |
|------------------------------|----------------------------------|
| ![Flutter](https://img.shields.io/badge/-Flutter-02569B?logo=flutter&logoColor=white) | Framework principal |
| ![Dart](https://img.shields.io/badge/-Dart-0175C2?logo=dart&logoColor=white) | Linguagem |
| ![Firebase](https://img.shields.io/badge/-Firebase-FFCA28?logo=firebase&logoColor=black) | Auth + Google Sign-In |
| ![Provider](https://img.shields.io/badge/-Provider-0175C2?logo=dart&logoColor=white) | Gerenciamento de estado |
| `flutter_secure_storage`     | Armazenamento seguro do nome |
| `flutter_local_notifications`| Notificações locais |
| `image_picker`               | Seleção / visualização de fotos |
| `http`                       | Comunicação com a API |
| `audioplayers`               | Feedback sonoro |
| `pusher_channels_flutter`    | Tempo real (quando ativo) |

---

## 🚀 Como rodar

```bash
# Clone
git clone https://github.com/deividjmoura/entregas-app.git
cd entregas-app

# Dependências
flutter pub get

# Configure o Firebase (primeira vez)
flutterfire configure

# Rode
flutter run
Importante: use o mesmo projeto Firebase do backend entregas-teste.

📱 Build Release (Android)
Bashflutter clean
flutter build apk --release
O APK fica em:
build/app/outputs/flutter-apk/app-release.apk

🗺️ Próximos Passos

 Assinatura real do APK (keystore de produção)
 Publicação na Play Store (Internal Testing)
 Melhorar feedback offline / retry automático
 Suporte a múltiplas fotos por solicitação
 Dashboard de métricas do entregador
 Notificações push (FCM) em vez de só locais
 Testes automatizados (unit + widget)
 CI/CD com GitHub Actions (build + release)


📂 Estrutura principal
textlib/
├── models/           # Solicitacao, Mensagem...
├── screens/          # Login, Fila, Detalhes, Chat...
├── services/         # Auth, Solicitacao, ApiClient
├── utils/            # Constantes, cores, labels
└── widgets/          # Componentes reutilizáveis

📄 Licença
Projeto privado / uso interno.


  Feito com 💙 usando Flutter

