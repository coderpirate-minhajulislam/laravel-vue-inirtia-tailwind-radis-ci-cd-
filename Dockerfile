name: Laravel CI/CD with Vue, Inertia.js, Tailwind CSS, Redis, MySQL, and FTP Deployment

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: ${{ secrets.MYSQL_ROOT_PASSWORD }}
          MYSQL_DATABASE: ${{ secrets.DB_DATABASE }}
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping --silent"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3

      redis:
        image: redis:alpine
        ports:
          - 6379:6379

    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Set up PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.2'
        extensions: mbstring, bcmath, zip, pdo, pdo_mysql, redis

    - name: Install Composer dependencies
      run: composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev

    - name: Copy .env.example to .env
      run: cp .env.example .env

    - name: Set environment variables
      run: |
        echo "DB_CONNECTION=mysql" >> .env
        echo "DB_HOST=${{ secrets.DB_HOST }}" >> .env
        echo "DB_PORT=3306" >> .env
        echo "DB_DATABASE=${{ secrets.DB_DATABASE }}" >> .env
        echo "DB_USERNAME=${{ secrets.DB_USERNAME }}" >> .env
        echo "DB_PASSWORD=${{ secrets.DB_PASSWORD }}" >> .env

    - name: Generate key
      run: php artisan key:generate

    - name: Set up Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '16'

    - name: Install npm dependencies
      run: npm install

    - name: Run database migrations
      run: php artisan migrate --force

    - name: Seed database
      run: php artisan db:seed --force

    - name: Run Laravel Artisan optimize commands
      run: |
        php artisan config:cache
        php artisan route:cache
        php artisan view:cache

    - name: Run tests
      run: php artisan test

    - name: Compile frontend assets for production
      run: npm run production

    - name: Deploy to shared hosting via FTP
      if: success()  # Only deploy if previous steps were successful
      run: |
        sudo apt-get update && sudo apt-get install -y lftp
        lftp -e "
          set ftp:ssl-allow no;  # Disable SSL if not supported by FTP server
          open -u ${{ secrets.FTP_USER }},${{ secrets.FTP_PASSWORD }} ${{ secrets.FTP_HOST }};
          mirror -R ./ /public_html/your-app-directory;  # Adjust path to your app's root on the server
          bye
        "
