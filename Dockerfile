# Stage 1: Build stage using OpenJDK 21 and Gradle 8.2.1
FROM openjdk:21-slim AS build

# Instala utilitários essenciais (wget e unzip) sem pacotes desnecessários
RUN apt-get update && apt-get install -y --no-install-recommends wget unzip && \
    rm -rf /var/lib/apt/lists/*

# Define a versão do Gradle e instala
ENV GRADLE_VERSION=8.13
RUN wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp && \
    unzip /tmp/gradle-${GRADLE_VERSION}-bin.zip -d /opt && \
    rm /tmp/gradle-${GRADLE_VERSION}-bin.zip && \
    ln -s /opt/gradle-${GRADLE_VERSION} /opt/gradle

# Adiciona o Gradle ao PATH
ENV PATH="/opt/gradle/bin:${PATH}"

WORKDIR /app

# Copia os arquivos de configuração do Gradle para aproveitar o cache das dependências
COPY build.gradle settings.gradle gradle.properties* /app/
# Se você utiliza o Gradle Wrapper, copie também
COPY gradlew /app/
COPY gradle/wrapper/ /app/gradle/wrapper/

# Baixa as dependências; essa camada será cacheada se os arquivos de configuração não mudarem
RUN gradle --no-daemon dependencies

# Copia o restante do código-fonte
COPY . .

# Compila e constrói a aplicação (certifique-se de que o fat jar seja gerado)
RUN gradle clean build --no-daemon

# Stage 2: Imagem final para execução com OpenJDK 21 e usuário não-root
FROM openjdk:21-slim

# Cria um usuário e grupo não-root para segurança
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

WORKDIR /app

# Copia o jar gerado na etapa de build
COPY --from=build /app/build/libs/aws-lab-1.0-SNAPSHOT.jar app.jar

# Ajusta permissões para o usuário não-root
RUN chown appuser:appgroup app.jar

# Exponha a porta da aplicação
EXPOSE 8080

# Muda para o usuário não-root
USER appuser

# Comando de inicialização
ENTRYPOINT ["java", "-jar", "app.jar"]
