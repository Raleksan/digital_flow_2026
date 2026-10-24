# Запуск LEC для изменённого RTL

Из каталога `lab2`:

```
make lec_nogui LEC_FILE=$PWD/task1_1/rtl2bug.lec.do
```

`rtl2bug.lec.do` — копия `run/genus/outputs/rtl2final.lec.do`, изменено:

- log пишется в `reports/rtl2bug.lec.log`;
- `add_search_path` указывает на `lab2/task1_1`;
- golden RTL читается из `task1_1/blockB_bug.lst`.
