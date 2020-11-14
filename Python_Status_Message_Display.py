class StatusMessage:
    def __init__(self, a=None, b=None, c=None, d=None):
        '''
            $MSG = text to be send
            $TYPE = ['ok', 'warn', 'fail', 'notice']
            $STYLE = ['1: display color/bold on [TAG]', '2: display color/bold on all']
            $ICON = [y, n]
        '''
        self.msg = a
        self.type = b
        self.style = c
        self.icon = d

    def meow(self):
        print('meow!')

    def p_msg(self, msg, type, style, icon):
        # Set colors to be called
        RED = '\033[31m'
        GREEN = '\033[32m'
        YELLOW = '\033[33m'
        CYAN = '\033[36m'
        BOLD = '\033[1m'
        RESET = '\033[0m'

        if type == 'ok':
            if icon == 'y':
                icon = '☑ '
            else:
                icon = ""
            if style == '1':
                print(GREEN + BOLD + f'{icon}[PURR]' + RESET + f' {msg}')
            if style == '2':
                print(GREEN + BOLD + f'{icon}[PURR] {msg}' + RESET)

        if type == 'warn':
            if icon == 'y':
                icon = '⚠ '
            else:
                icon = ""
            if style == '1':
                print(YELLOW + BOLD + f'{icon}[RAWR]' + RESET + f' {msg}')
            if style == '2':
                print(YELLOW + BOLD + f'{icon}[RAWR] {msg}' + RESET)

        if type == 'fail':
            if icon == 'y':
                icon = '☒ '
            else:
                icon = ""
            if style == '1':
                print(RED + BOLD + f'{icon}[HISS]' + RESET + f' {msg}')
            if style == '2':
                print(RED + BOLD + f'{icon}[HISS] {msg}' + RESET)

        if type == 'notice':
            if icon == 'y':
                icon = '😺 '
            else:
                icon = ""
            if style == '1':
                print(CYAN + BOLD + f'{icon}[MEOW]' + RESET + f' {msg}')
            if style == '2':
                print(CYAN + BOLD + f'{icon}[MEOW] {msg}' + RESET)

sm = StatusMessage()

while True:
    try:
        y = int(input('Please enter a number\n'))
        print(y)
    except ValueError as ve:
        sm.p_msg(ve, 'warn', '2', 'y')
    except TypeError as te:
        sm.p_msg(te, 'warn', '2', 'y')
