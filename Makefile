# Makefile для практического занятия по мониторингу Kubernetes
# Простое развертывание Prometheus + Grafana + Loki

NAMESPACE = monitoring
DEMO_NAMESPACE = demo-app

.PHONY: help install-all install-prometheus install-loki install-demo clean clean-all status grafana-password port-forward-grafana port-forward-prometheus import-dashboard

# Показать справку
help:
	@echo "Доступные команды:"
	@echo "  install-all                - Установить весь стек мониторинга"
	@echo "  install-prometheus         - Установить Prometheus + Grafana"
	@echo "  install-loki               - Установить Loki для логирования"
	@echo "  install-demo               - Установить демо-приложение"
	@echo "  status                     - Проверить статус всех компонентов"
	@echo "  grafana-password           - Показать пароль для Grafana"
	@echo "  port-forward-grafana       - Запустить порт-форвард для Grafana"
	@echo "  port-forward-prometheus    - Запустить порт-форвард для Prometheus"
	@echo "  import-dashboard           - Показать инструкции по импорту дашборда"
	@echo "  clean                      - Удалить демо-приложение"
	@echo "  clean-all                  - Удалить весь стек мониторинга"
	@echo ""

# Установить весь стек
install-all: install-prometheus install-loki install-demo
	@echo "Все компоненты установлены!"
	@echo "Запустите 'make grafana-password' чтобы получить пароль для Grafana"
	@echo "Запустите 'make port-forward-grafana' для доступа к Grafana"

# Подготовка и установка Helm репозиториев
setup-helm:
	@echo "Добавляем Helm репозитории..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update
	@echo "Helm репозитории обновлены"

# Установка Prometheus + Grafana
install-prometheus: setup-helm
	@echo "🚀 Устанавливаем Prometheus Stack..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
		--namespace $(NAMESPACE) \
		--values values-prometheus.yaml \
		--wait
	@echo "Prometheus Stack установлен"

# Установка Loki для логирования
install-loki: setup-helm
	@echo "Устанавливаем Loki Stack..."
	helm upgrade --install loki grafana/loki-stack \
		--namespace $(NAMESPACE) \
		--set grafana.enabled=false \
		--set prometheus.enabled=false \
		--set loki.persistence.enabled=true \
		--set loki.persistence.size=10Gi \
		--wait
	@echo "Loki Stack установлен"
	@echo "Loki автоматически настроен как источник данных в Grafana"

# Установка демо-приложения
install-demo:
	@echo "Устанавливаем демо-приложение..."
	kubectl create namespace $(DEMO_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f demo-app/
	@echo "Демо-приложение установлено"
	@echo "Дашборд находится в файле dashboards/demo-app-dashboard.json"
	@echo "Импортируйте его в Grafana: Dashboard → Import → Upload JSON file"

# Проверить статус всех компонентов
status:
	@echo "=== Статус компонентов ==="
	@echo ""
	@echo "Мониторинг namespace:"
	kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "Демо-приложение namespace:"
	kubectl get pods -n $(DEMO_NAMESPACE)
	@echo ""
	@echo "Сервисы:"
	kubectl get svc -n $(NAMESPACE)

# Получить пароль для Grafana
grafana-password:
	@echo "Пароль для Grafana (пользователь: admin):"
	@kubectl get secret -n $(NAMESPACE) monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
	@echo ""

# Порт-форвард для Grafana
port-forward-grafana:
	@echo "Запускаем порт-форвард для Grafana..."
	@echo "Grafana будет доступна по адресу: http://localhost:3000"
	@echo "Пользователь: admin"
	@make grafana-password
	kubectl port-forward -n $(NAMESPACE) svc/monitoring-grafana 3000:80

# Порт-форвард для Prometheus
port-forward-prometheus:
	@echo "Запускаем порт-форвард для Prometheus..."
	@echo "Prometheus будет доступен по адресу: http://localhost:9090"
	kubectl port-forward -n $(NAMESPACE) svc/monitoring-kube-prometheus-prometheus 9090:9090

# Удалить демо-приложение
clean:
	@echo "Удаляем демо-приложение..."
	kubectl delete namespace $(DEMO_NAMESPACE) --ignore-not-found=true
	@echo "Демо-приложение удалено"

# Инструкции по импорту дашборда
import-dashboard:
	@echo "Как импортировать дашборд в Grafana:"
	@echo ""
	@echo "1. Откройте Grafana: http://localhost:3000"
	@echo "2. Войдите: admin / otus123"
	@echo "3. Перейдите в: Dashboard → Import"
	@echo "4. Нажмите 'Upload JSON file'"
	@echo "5. Выберите файл: dashboards/demo-app-dashboard.json"
	@echo "6. Нажмите 'Import'"
	@echo ""
	@echo "Альтернативно:"
	@echo "Скопируйте содержимое dashboards/demo-app-dashboard.json"
	@echo "и вставьте в поле 'Import via panel json'"

# Удалить весь стек мониторинга
clean-all:
	@echo "Удаляем весь стек мониторинга..."
	helm uninstall monitoring -n $(NAMESPACE) --ignore-not-found
	helm uninstall loki -n $(NAMESPACE) --ignore-not-found
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	kubectl delete namespace $(DEMO_NAMESPACE) --ignore-not-found=true
	@echo "Все компоненты удалены" 