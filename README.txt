Что нужно:

0. линукс с davfs2, unison, perl >5.10.

1. Запись в fstab со скрытой точкой монтирования в $HOME вида:
https://webdav.yandex.ru	/home/kappa/.yadisk-davfs	davfs	noauto,user	0 0

2. Секрет в ~/.davfs2/secrets вида:
/home/kappa/.yadisk-davfs	kappa@yandex.ru	<ПАРОЛЬ>

2.5. chown kappa:kappa ~/.davfs2/secrets && chmod 600 ~/.davfs2/secrets

3. sudo dpkg-reconfigure davfs2 --> разрешить монтирование davfs2
обычным пользователям (не знаю, как это делается не на Убунте).

4. sudo usermod -a -G davfs2 kappa # добавить пользователя в группу davfs2

4.5. теперь можно сделать mount /home/kappa/.yadisk-davfs2 без sudo

5. ~/.yadiskrc по примеру

6. нужна пачка перловых модулей, а именно:
uni::perl, autodie, Config::Tiny, AnyEvent::Inotify::Simple, EV, AnyEvent::XMPP
поставить их можно например так:
$ curl -L http://cpanmin.us | perl - --self-upgrade
$ cpanm <список модулей через пробел>

7. yadisk-sync.pl не демонизируется, пока лучше посматривать за ним в
консоли.

8. xmpp.pl -- заготовка для приёма пушей, для работы не нужна.
