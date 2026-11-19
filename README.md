# 2627_2A_FPGA_FERLY_MOISDON


Faire clignoter une LED :

FPGA_CLK1_50 est connectée sur le PIN_V11. 

On fait le schéma du code :
<img width="1118" height="597" alt="image" src="https://github.com/user-attachments/assets/d0345b13-f90a-4573-8802-cf67b8445f60" />

Le schéma proposé par Quartus est le suivant :

<img width="982" height="307" alt="image" src="https://github.com/user-attachments/assets/e88ae7fd-c3a5-4195-a50d-fcbb4a53cd87" />

On remarque que le bascule D n'est pas affichée directetement.

Schéma du nouveau code :
<img width="1600" height="1389" alt="image" src="https://github.com/user-attachments/assets/2fd774ee-99b2-468b-b303-67d6a7795fd5" />

Résultat RLT :

<img width="1447" height="363" alt="image" src="https://github.com/user-attachments/assets/0fb6ad81-8443-407d-a82b-59bcbd9cd0a9" />



TP - Télécran
Noé Moisdon

Question 2 : 
Afin de détecter un front montant ( ou descendant ), nous allons utiliser des bascules D. Pour cela nous en plaçons deux à la suite. Puis nous prenons deux signaux, un qui correspond à l’état actuel (t), le signal A_ACT, et un autre qui correspond à l’état précédent ( t-1), le signal A_PREC. Ensuite, pour détecter les fronts montant il suffira de remarquer que le signal A_PREC vaut 1 alors que le signal A_ACT vaut 0. Et inversement pour le front descendant.

Mémorisation : 
Question 1 : Une mémoire dual-port, c'est une mémoire qui autorise simultanément l'accès à deux interfaces, en l'occurence ici nous avons le port A, ainsi le port B qui sont complètement distinct.

Question 2 : Voici le schéma demandé : 
<img width="1080" height="792" alt="WhatsApp Image 2026-11-19 at 09 47 04" src="https://github.com/user-attachments/assets/c35616e6-ed54-4288-a8b4-8b17461d6210" />

Effacement : 
Question 1 : Dans le FPGA, la mémoire dpRAM interne (Block RAM) ne dispose pas d'entrée de remise à zéro globale permettant d'effacer toutes les données instantanément. Pour vider l'écran, il faut donc que nous balayons séquentiellement l'ensemble des $345\,600$ adresses ($720 \times 480$) afin d'y écrire la valeur 0x00 une par une.Notre solution consiste à ajouter un multiplexeur d'accès sur le Port A de la mémoire, piloté par un compteur d'effacement :En fonctionnement normal : Le Port A reçoit l'adresse correspondant aux coordonnées $(X, Y)$ issues des deux encodeurs ($\text{Adresse} = Y \times 720 + X$) et écrit 0x01 pour mémoriser le passage du pixel.Lors de l'appui sur le bouton (i_left_pb) : Le système bascule alors en mode effacement ; le compteur parcourt automatiquement toutes les adresses de 0 à 345599 au rythme de l'horloge à 50 MHz en écrivant 0x00 à chaque cycle, puis redonne la main aux encodeurs une fois le balayage terminé.




