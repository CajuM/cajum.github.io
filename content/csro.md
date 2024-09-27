+++
date = 2024-07-13
title = "Cum să îți amăgești audiența: Reportajul Recorder, \"Clanul Marelui Alb\""
+++

În sfera credinței deseori apar neadevăruri. Fie că acestea vin din partea guvernelor, a ereticilor sau a neștiutorilor. În acest articol vom încerca să lămurim o tentativă de fraudă din partea unei agenții de presă ce se bucură de atenția unei populații semnificative din România.

În reportajul din 2021, reporterii Recorder[7] pretind demascarea activităților de clan mafiot ale Bisericii Ortodoxe Române. Reportajul are ca scop analiza deturnării de fonduri ale Statului Român prin umflarea prețurilor aferente construcției sau renovării de lăcașuri de cult. Ca studiu de caz este abordată renovarea Mânăstirii Chiajna-Giulești. Ca dovadă a fraudei, este prezentat un document ce conține o parte din costurile renovării[1].

Reporterul ne atrage atenția asupra prețului unitar al manoperei aferente capitolului RPIC70E1, susținând că este de zece ori mai mare decât prețul pieței(25.56[1] vs 3.62[3]). Ca dovadă, ne arată o captură de ecran a programului eDevize[2]. Reporterul nu menționează direct numele programului, ci doar că este folosit de "majoritatea constructorilor din România"[6]. Pentru a confirma că programul este într-adevăr eDevize putem căuta o captura de ecran a programului[2]. După cum putem observa, butoanele de la "Cauta articol" la "Proprietăți" sunt identice, inclusiv lipsa diacriticelor. Din taburi lipsește "Fraht", dar asta nu este o problemă deoarece pot apărea schimbări în interfață între versiuni. Diferențele de aspect ale interfeței se datorează faptului că reporterul folosește versiunea macOS a programului.

Pentru a ne induce în eroare, reporterul ne prezintă o captură de ecran din programul eDevize care afișează "prețul pieței"[3]. Dacă ne uităm cu atenție la captura de ecran a eDevize[2], observăm că ne este arătat prețul total în loc de cel unitar cu valoarea cantității setată la o valoare convenabilă(0.17)[3]. Pentru a ne verifica ipoteza este suficient un simplu calcul:
```
Preț total = cantiate * Preț unitar
           = 0.17 * 21.27
           = 3.616
```
Cu erori de rotunjire este aproximativ egal cu 3.62[3]. În captura de ecran observăm că au fost micșorate coloanele astfel încât nu putem distinge între prețul unitar și cel total[3]. Însă, dacă ne uităm la captura de mai devreme[2], observăm ca ordinea coloanelor este "Preț unitar" și apoi "Preț total".

În cazul capitolului CF48B02, reporterul ne spune doar că "specialiștii pe care i-am consultat spun că ... nu putea fi mai mare de 15 lei pe metru pătrat", fără să aducă vreo dovadă[4]. În același timp putem observa că unele câmpuri pentru prețul unitar au fost șterse: material, utilaj, transport[3]. Deși valorile lor au fost folosite în calculul prețului total. Spre exemplu câmpul "material" are o valoare de:
```
material = (Preț unitar total - manoperă)
         = 59.23 - 28.55
         = 30.68
```
Pentru a ne verifica, putem calcula manopera în alt fel:
```
material = (Preț total - Preț total manoperă) / Cantitate
         = (18953.60 - 9136) / 320
         = 30.68
```

Ca ultimă dovadă, reporterul ne indică prețul umflat al capitolului CN04A1, menționând că a fost umflat de patru ori. Dar, și în acest exemplu, este folosit trucul de mai devreme. Ne este spus că prețul umflat unitar al manoperei este de 25.56[1], în timp ce ne este arătat, în loc, prețul total al manoperei de 6.64. Și în acest caz cantitatea are o valoare fictivă de 0.31 ore, în timp ce prețul unitar, raportat de eDevize, este de 21.42[5].

Examinând documentul[1], observăm că ultimul capitol este gol, deși unele din câmpurile numerice au valori. Din moment ce restul capitolelor au o descriere ce este aliniată la vârful celulei, ne putem întreba dacă documentul prezentat a fost editat?

În concluzie am prezentat o analiză a unor erori punctuale ale celor de la Recorder, opinia mea personală este ca acestea nu au fost coincidențe, ci minciuni deliberate.

[1] [Formular Devize](https://youtu.be/qHTgt82ZGPM?feature=shared&t=2308)

[2] [eDevize](https://youtu.be/Kuzw6vJBQjQ?feature=shared&t=2)

[3] [RPIC70E1 eDevize](https://youtu.be/qHTgt82ZGPM?feature=shared&t=2321)

[4] [CF48B02 Specialiști](https://youtu.be/qHTgt82ZGPM?feature=shared&t=2338)

[5] [CN04A1 eDevize](https://youtu.be/qHTgt82ZGPM?feature=shared&t=2365)

[6] [popularitate eDevize](https://youtu.be/qHTgt82ZGPM?feature=shared&t=2270)

[7] [Recorder](https://recorder.ro/)
