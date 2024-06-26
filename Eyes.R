# Chargement des bibliothèques nécessaires
library(ggplot2)
library(coda)

# Initialisation des paramètres
N <- 48# Nombre total d'observations
y <- c(529, 530, 532, 533.1, 533.4, 533.6, 533.7, 534.1, 534.8, 535.3, 
       535.4, 535.9, 536.1, 536.3, 536.4, 536.6, 537, 537.4, 537.5, 
       538.3, 538.5, 538.6, 539.4, 539.6, 540.4, 540.8, 542, 542.8, 
       543, 543.5, 543.8, 543.9, 545.3, 546.2, 548.8, 548.7, 548.9, 
       549, 549.4, 549.9, 550.6, 551.2, 551.4, 551.5, 551.6, 552.8, 
       552.9, 553.2)# Données observées

# Paramètres a priori
alpha <- c(1, 1)  # Paramètres de la loi Beta pour p1
lambda_1 <- 535  # Moyenne initiale du premier groupe
theta <- 5  # Différence initiale entre les moyennes des deux groupes
sigmasq <- 10  # Variance initiale commune aux deux groupes
p1 <- 0.5  # Probabilité initiale qu'une observation appartienne au premier groupe


###########               algorithme MH                 ##############
set.seed(4537)
lambda <- c(lambda_1, lambda_1 + theta)  # Moyennes des groupes
p <- c(p1, 1 - p1)                       # Proportions des groupes
iterations <- 10000
chain <- matrix(NA, nrow = iterations, ncol = 4)  # Pour stocker les échantillons


# Fonction pour calculer la log_vraisemblance d'une loi normale bimodale
log_vraisemblance <- function(y, lambda, sigmasq, p) {
  sum(log(p[1] * dnorm(y, lambda[1], sqrt(sigmasq)) +
            p[2] * dnorm(y, lambda[2], sqrt(sigmasq))))}

# Matrice pour stocker les échantillons de la chaîne MCMC
chain <- matrix(NA, nrow = iterations, ncol = 4)
colnames(chain) <- c("lambda1", "lambda2", "sigmasq", "p1")

# Valeur initiale de la log_vraisemblance
Actu_log_vraisemblance <- log_vraisemblance(y, lambda, sigmasq, p)

for (i in 1:iterations) {
  # Proposition de nouveaux paramètres en ajoutant une perturbation gaussienne
  lambda_prop <- rnorm(2, mean = c(lambda_1, lambda_1 + theta), sd = c(1, 1))
  sigmasq_prop <- rnorm(1, mean = sigmasq, sd = 1)
  p_prop <- runif(1, min = 0, max = 1)
  
  # Calcul de la nouvelle log_vraisemblance avec les paramètres proposés
  prop_log_vraisemblance <- log_vraisemblance(y, lambda_prop, sigmasq_prop, c(p_prop, 1 - p_prop))
  
  # Calcul de la probabilité d'acceptation (ratio de Hastings)
  alpha <- exp(prop_log_vraisemblance - Actu_log_vraisemblance)
  
  # Décider d'accepter ou de rejeter la nouvelle proposition
  if (runif(1) < alpha) {
    lambda_1 <- lambda_prop[1]
    theta <- lambda_prop[2] - lambda_1
    sigmasq <- sigmasq_prop
    p1 <- p_prop
    Actu_log_vraisemblance <- prop_log_vraisemblance
  }
  
  # Stocker la chaîne
  chain[i, ] <- c(lambda_1, lambda_1 + theta, sigmasq, p1)
}

# Analyse des résultats avec un burn-in
mcmc_chain1 <- mcmc(chain[-(1:1000), ])  # Burn-in de 1000 itérations
par(mar=c(4, 4, 2, 2))
plot(mcmc_chain1)

summary(mcmc_chain1)

#pdf("MH_plot.pdf")  # pdf ou jpeg


# Données après le burn-in
effective_chain <- chain[-(1:1000), ]

# Graphiques
par(mfrow=c(1,1))
ggplot(data.frame(lambda1 = effective_chain[, "lambda1"]), aes(x = lambda1)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 0.5, fill = "skyblue", color = "black") +
  geom_density(alpha = .2, fill = "#FF6666") +
  labs(title = "loi de Lambda1", x = "Lambda1", y = "Densité") +
  theme_minimal()

ggplot(data.frame(lambda2 = effective_chain[, "lambda2"]), aes(x = lambda2)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 0.5, fill = "skyblue", color = "black") +
  geom_density(alpha = .2, fill = "#FF6666") +
  labs(title = "loi de Lambda2", x = "Lambda2", y = "Densité") +
  theme_minimal()

ggplot(data.frame(sigmasq = effective_chain[, "sigmasq"]), aes(x = sigmasq)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 1, fill = "skyblue", color = "black") + # Tu peux ajuster le binwidth si nécessaire
  geom_density(alpha = .2, fill = "#FF6666") +
  labs(title = "loi de Sigmasq", x = "Sigmasq", y = "Densité") +
  theme_minimal()

ggplot(data.frame(p1 = effective_chain[, "p1"]), aes(x = p1)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 0.02, fill = "skyblue", color = "black") + # Tu peux ajuster le binwidth si nécessaire
  geom_density(alpha = .2, fill = "#FF6666") +
  labs(title = "loi de p1", x = "p1", y = "Densité") +
  theme_minimal()

#Résultats
summary_stats <- apply(effective_chain, 2, function(x) {
  c(mean = mean(x), sd = sd(x), `2.5%` = quantile(x, 0.025), `97.5%` = quantile(x, 0.975))
})
summary_stats

#################****Avec préchauffe******###############

# Diagnostic et résumé de la chaîne (après une période d'échauffement et d'amincissement)
chauffe <- floor(0.1 * iterations)
chain_chauffé <- chain[-(1:chauffe), ]
mcmc_chain2 <- mcmc(chain_chauffé)

# Création des graphiques de diagnostics MCMC
par(mar=c(4, 4, 2, 2))
plot(mcmc_chain2)


# Résumé statistique des chaînes MCMC
summary(mcmc_chain2)


###########              algorithme Gibbs                 ##############
set.seed(12345)
p <- c(p1, 1 - p1)
lambda <- c(lambda_1, lambda_1 + theta)
iterations <- 10000
chain_Gibbs <- matrix(NA, nrow = iterations, ncol = 4)
# Affectations initiales basées sur les proportions p
T <- sample(1:2, length(y), replace = TRUE, prob = p)

for (i in 1:iterations) {
  # Mise à jour des affectations T
  for (j in 1:length(y)) {
    prob1 <- p[1] * dnorm(y[j], lambda[1], sqrt(sigmasq))
    prob2 <- p[2] * dnorm(y[j], lambda[2], sqrt(sigmasq))
    T[j] <- sample(1:2, 1, prob = c(prob1, prob2))
  }
  
  # Mise à jour de lambda1 et lambda2
  lambda[1] <- rnorm(1, mean(y[T == 1]), sd = sqrt(sigmasq / length(y[T == 1])))
  lambda[2] <- rnorm(1, mean(y[T == 2]), sd = sqrt(sigmasq / length(y[T == 2])))
  
  # Mise à jour de sigmasq
  sigma2 <- (sum((y[T == 1] - lambda[1])^2) + sum((y[T == 2] - lambda[2])^2)) / length(y)
  
  # Mise à jour de p
  p[1] <- mean(T == 1)
  p[2] <- 1 - p[1]
  
  # Stockage des échantillons
  chain_Gibbs[i, ] <- c(lambda[1], lambda[2], sigma2, p[1])
}

# Graphiques pour l'analyse de convergence des chaînes
par(mfrow=c(2,2))
noms_graphiques <- c(expression(lambda[1]), expression(lambda[2]), expression(sigma^2), 'p[1]')
for (i in 1:4) {
  plot(chain_Gibbs[,i], type='l', main=noms_graphiques[i], xlab='Itération', ylab='Valeur', col='blue')
}

# Histogrammes des lois a posteriori
par(mfrow=c(2,2))
for (i in 1:4) {
  hist(chain_Gibbs[,i], breaks=40, probability=TRUE, main=noms_graphiques[i], xlab='Valeur', ylab='Densité', col='darkgrey', border='blue')
  lines(density(chain_Gibbs[,i]), col='blue')
}

# Histogrammes des lois a posteriori avec ggplot2
colnames(chain_Gibbs) <- c('lambda1', 'lambda2', 'sigma2', 'p1')
chain_df_Gibbs <- as.data.frame(chain_Gibbs)
for (i in colnames(chain_df_Gibbs)) {
  p <- ggplot(chain_df_Gibbs, aes(x=.data[[i]])) +
    geom_histogram(aes(y=after_stat(density)), bins=30, fill='blue', color='black', alpha=0.7) +
    geom_density(color='red', linewidth=1) +
    labs(title=paste('Loi a posteriori de', i), x='Valeur', y='Densité')
  print(p)
}
# Graphiques d'autocorrélation
par(mfrow=c(2,2))
for (i in 1:4) {
  acf(chain_Gibbs[,i], main=paste('Autocorrélation de', colnames(chain_Gibbs)[i]))
}


# Analyse des résultats avec coda
library(coda)
mcmc_chain3 <- mcmc(chain_Gibbs[-(1:1000), ])  # Burn-in de 1000 itérations
par(mar=c(4, 4, 2, 2))
plot(mcmc_chain3)

#pdf("Gibbs8.png")  # pdf ou jpeg

summary(mcmc_chain3)


#################****Avec préchauffe******###############

# Prétraitement des résultats (burn-in et échantillonnage)
burnin <- floor(0.1 * iterations)  # Définition du nombre d'itérations à brûler
chain_net <- chain_Gibbs[-(1:burnin),]    # Chaîne nettoyée sans les itérations brûlées
chain_aminc <- chain_net[seq(1, nrow(chain_net), by=10),]  # Chaîne amincie

# Résumé des résultats statistique de la chaîne amincie
print(summary(chain_aminc))

# Graphiques pour l'analyse de convergence des chaînes
par(mfrow=c(2,2))
noms_graphiques <- c(expression(lambda[1]), expression(lambda[2]), expression(sigma^2), 'p[1]')
for (i in 1:4) {
  plot(chain_aminc[,i], type='l', main=noms_graphiques[i], xlab='Itération', ylab='Valeur', col='blue')
}

# Histogrammes des lois a posteriori
par(mfrow=c(2,2))
for (i in 1:4) {
  hist(chain_Gibbs[,i], breaks=40, probability=TRUE, main=noms_graphiques[i], xlab='Valeur', ylab='Densité', col='darkgrey', border='blue')
  lines(density(chain_Gibbs[,i]), col='blue')
}

# Histogrammes des lois a posteriori avec ggplot2
colnames(chain_aminc) <- c('lambda1', 'lambda2', 'sigma2', 'p1')
chain_df <- as.data.frame(chain_aminc)
for (i in colnames(chain_df)) {
  p <- ggplot(chain_df, aes_string(x=i)) +
    geom_histogram(aes(y=after_stat(density)), bins=30, fill='blue', color='black', alpha=0.7) +
    geom_density(color='red', linewidth=1) +
    labs(title=paste('Loi a posteriori de', i), x='Valeur', y='Densité')
  print(p)
}

# Graphiques d'autocorrélation
par(mfrow=c(2,2))
for (i in 1:4) {
  acf(chain_Gibbs[,i], main=paste('Autocorrélation de', colnames(chain_Gibbs)[i]))
}


