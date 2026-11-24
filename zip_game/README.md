# zip_game: app Flutter de ZIP Game

Frontend del proyecto ZIP Game (Flutter 3.50 + `material_ui`, `http` y `shared_preferences`).
La documentación completa (instalación, endpoints, diagrama ER y reglas) está en el [README principal](../README.md).

```powershell
flutter pub get
flutter run -d chrome                                    # API en http://localhost:3333/api
flutter run --dart-define=API_URL=http://10.0.2.2:3333/api   # emulador Android
flutter test                                             # 25 pruebas
flutter test test/integration --dart-define=INTEGRATION=true # con el backend encendido
```
