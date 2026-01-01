import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from tkinterdnd2 import DND_FILES, TkinterDnD
from PIL import Image, ImageTk
import os
import re
import sys

class PortraitMaker:
    def __init__(self, root):
        self.root = root
        self.root.title("초상화 만들기 v2.0.1") # 버전 유지
        
        # --- 경로 설정 최적화 (빌드 대응) ---
        if getattr(sys, 'frozen', False):
            self.base_dir = os.path.dirname(sys.executable)
            self.resource_path = sys._MEIPASS 
        else:
            self.base_dir = os.path.dirname(os.path.abspath(__file__))
            self.resource_path = self.base_dir

        # 아이콘 설정 (복구 완료)
        try:
            icon_path = os.path.join(self.resource_path, "icon.ico")
            if os.path.exists(icon_path):
                self.root.iconbitmap(icon_path)
        except Exception as e:
            print(f"아이콘 로드 실패: {e}")

        # 테마 및 설정 (원본 수치 복구)
        self.bg_dark = "#1e1e1e"
        self.bg_panel = "#252a30"
        self.accent_color = "#ffc107"
        self.text_white = "#ffffff"
        self.text_gray = "#aaaaaa"
        self.btn_disabled_bg = "#333a45"
        self.btn_disabled_fg = "#666666"
        
        self.main_font = ("Malgun Gothic", 13)
        self.bold_font = ("Malgun Gothic", 13, "bold")
        self.safe_margin = 21
        self.rect_width = 1
        self.min_size = 40
        self.frame_padding = 1
        
        self.root.option_add("*TCombobox*Listbox.font", self.main_font)
        
        sw, sh = self.root.winfo_screenwidth(), self.root.winfo_screenheight()
        start_w, start_h = int(sw*0.8), int(sh*0.8)
        self.root.geometry(f"{start_w}x{start_h}+20+20")
        self.root.minsize(start_w, start_h)
        
        self.last_width = start_w
        self.last_height = start_h
        
        self.root.configure(bg=self.bg_dark)
        
        self.original_img = None
        self.display_img = None
        self.tk_display_img = None
        self.scale_ratio = 1.0
        self.step = "IDLE" 
        self.step_idx = 0

        self.configs = {
            "D&D EE (BG1, BG2, IWD1)": {
                "steps": ["Large", "Medium"], 
                "sizes": {"Large": (652, 1024), "Medium": (652, 1024)},
                "format": "BMP", "suffix": {"Large": "L", "Medium": "M"}
            },
            "D&D Classics (BG1, BG2, IWD1)": {
                "steps": ["Large", "Medium", "Small"], 
                "sizes": {"Large": (210, 330), "Medium": (110, 170), "Small": (38, 60)},
                "format": "BMP", "suffix": {"Large": "L", "Medium": "M", "Small": "S"}
            },
            "Icewind Dale 2 Classic": {
                "steps": ["Large", "Small"], 
                "sizes": {"Large": (210, 330), "Small": (42, 42)},
                "format": "BMP", "suffix": {"Large": "L", "Small": "S"}
            },
            "Pathfinder: Kingmaker & WotR": {
                "steps": ["FullLength", "Medium", "Small"], 
                "sizes": {"FullLength": (692, 1024), "Medium": (330, 432), "Small": (185, 242)},
                "format": "PNG", "use_folder": True
            },
            "Pillars of Eternity 1 & 2": {
                "steps": ["Large", "Small"],
                "sizes": {"Large": (210, 330), "Small": (76, 96)},
                "format": "PNG", "suffix": {"Large": "_lg", "Small": "_sm"}
            }
        }

        self.char_name_var = tk.StringVar(value="MYCHAR")
        self.char_name_var.trace_add("write", self.limit_char_name)
        
        self.setup_styles()
        self.setup_ui()
        self.root.bind("<Configure>", self.on_window_resize)

        self.root.drop_target_register(DND_FILES)
        self.root.dnd_bind('<<Drop>>', self.handle_drop)

    def setup_styles(self):
        style = ttk.Style()
        style.theme_use('clam')
        style.configure("TCombobox", fieldbackground=self.bg_dark, background=self.bg_panel, 
                        foreground=self.text_white, arrowcolor=self.accent_color, font=self.main_font)

    def setup_ui(self):
        self.header = tk.Frame(self.root, bg=self.bg_dark)
        self.header.pack(side="top", fill="x")
        tk.Label(self.header, text="Portraits Maker", font=("Malgun Gothic", 22, "bold"), 
                 fg=self.text_white, bg=self.bg_dark, pady=20).pack()

        self.main_container = tk.Frame(self.root, bg=self.bg_dark)
        self.main_container.pack(expand=True, fill="both")

        self.ctrl_panel = tk.Frame(self.main_container, width=320, bg=self.bg_panel, padx=25, pady=30)
        self.ctrl_panel.pack(side="right", fill="y", padx=10, pady=10)
        self.ctrl_panel.pack_propagate(False)

        tk.Label(self.ctrl_panel, text="게임 선택", font=("Malgun Gothic", 11, "bold"), fg=self.accent_color, bg=self.bg_panel).pack(anchor="w", pady=(0, 10))
        self.game_select = ttk.Combobox(self.ctrl_panel, values=list(self.configs.keys()), state="readonly", style="TCombobox", font=self.main_font)
        self.game_select.current(0)
        self.game_select.pack(fill="x", pady=(0, 30))
        self.game_select.bind("<<ComboboxSelected>>", lambda e: self.reset_crop_process())

        tk.Label(self.ctrl_panel, text="캐릭터 이름", font=("Malgun Gothic", 11, "bold"), fg=self.accent_color, bg=self.bg_panel).pack(anchor="w", pady=(0, 10))
        self.name_entry = tk.Entry(self.ctrl_panel, textvariable=self.char_name_var, font=self.main_font, bg=self.bg_dark, fg=self.text_white, insertbackground="white", bd=0, highlightthickness=1, highlightbackground="#444")
        self.name_entry.pack(fill="x", ipady=10, pady=(0, 40))

        self.btn_load = tk.Button(self.ctrl_panel, text="이미지 불러오기", command=self.load_image, bg="#333a45", fg=self.text_white, font=self.bold_font, activebackground=self.accent_color, relief="flat", cursor="hand2")
        self.btn_load.pack(fill="x", ipady=12)

        self.bottom_btn_frame = tk.Frame(self.ctrl_panel, bg=self.bg_panel)
        self.bottom_btn_frame.pack(side="bottom", fill="x")

        self.btn_retry = tk.Button(self.bottom_btn_frame, text="다시 처음부터", command=self.reset_crop_process, bg=self.btn_disabled_bg, fg=self.btn_disabled_fg, font=self.main_font, relief="flat", state="disabled")
        self.btn_retry.pack(fill="x", ipady=12, pady=(0, 10))

        self.btn_save = tk.Button(self.bottom_btn_frame, text="최종 저장", command=self.save_portraits, bg="#444444", fg=self.btn_disabled_fg, font=self.bold_font, relief="flat", state="disabled")
        self.btn_save.pack(fill="x", ipady=15)

        self.work_panel = tk.Frame(self.main_container, bg=self.bg_dark)
        self.work_panel.pack(side="left", expand=True, fill="both", padx=10, pady=10)

        self.status_label = tk.Label(self.work_panel, text="이미지 파일을 이 곳에 끌어다 놓으세요", fg=self.text_gray, bg=self.bg_dark, font=("Malgun Gothic", 14))
        self.status_label.pack(expand=True)

        self.workspace = tk.Frame(self.work_panel, bg=self.bg_dark)
        self.workspace.pack(expand=True, fill="both")

        self.canvas = tk.Canvas(self.workspace, bg=self.bg_dark, highlightthickness=0, bd=0)
        self.canvas.place(relx=0.5, rely=0.5, anchor="center")
        self.canvas.bind("<ButtonPress-1>", self.on_click)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<Motion>", self.update_cursor)

        self.btn_next = tk.Button(self.work_panel, text="자르기 ▶", command=self.next_step, bg=self.accent_color, fg=self.bg_dark, font=self.bold_font, relief="flat", state="disabled")

        self.review_frame = tk.Frame(self.workspace, bg=self.bg_dark)

    def handle_drop(self, event):
        path = event.data
        if path.startswith('{') and path.endswith('}'):
            path = path[1:-1]
        
        valid_extensions = ('.jpg', '.jpeg', '.png', '.bmp', '.webp')
        if path.lower().endswith(valid_extensions):
            self.process_image(path)
        else:
            messagebox.showwarning("경고", "지원하지 않는 파일 형식입니다.")

    def load_image(self):
        path = filedialog.askopenfilename(filetypes=[("이미지 파일", "*.jpg *.jpeg *.png *.bmp *.webp")])
        if not path: return
        self.process_image(path)

    def process_image(self, path):
        try:
            self.original_img = Image.open(path)
            self.refresh_display_size()
            self.reset_crop_process()
        except Exception as e:
            messagebox.showerror("에러", f"이미지를 불러올 수 없습니다: {e}")

    def refresh_display_size(self):
        if not self.original_img: return
        self.root.update_idletasks()
        avail_h = self.work_panel.winfo_height() - (self.safe_margin * 2) - 150
        avail_w = self.work_panel.winfo_width() - (self.safe_margin * 2)
        if avail_h < 100 or avail_w < 100: return
        
        img_w, img_h = self.original_img.size
        self.scale_ratio = min(avail_w/img_w, avail_h/img_h, 1.0)
        display_w, display_h = int(img_w * self.scale_ratio), int(img_h * self.scale_ratio)
        self.display_img = self.original_img.resize((display_w, display_h), Image.LANCZOS)
        self.tk_display_img = ImageTk.PhotoImage(self.display_img)
        self.canvas.config(width=display_w + (self.safe_margin * 2), height=display_h + (self.safe_margin * 2))

    def reset_crop_process(self):
        if not self.original_img: return
        game_cfg = self.configs[self.game_select.get()]
        self.step_idx, self.current_steps, self.crops = 0, game_cfg["steps"], {}
        self.step = "CROPPING"
        self.review_frame.place_forget()
        self.canvas.place(relx=0.5, rely=0.5, anchor="center")
        self.btn_next.pack(pady=30, ipady=12, ipadx=60)
        
        self.btn_next.config(state="normal", bg=self.accent_color)
        self.btn_save.config(state="disabled", bg="#444444")
        self.btn_retry.config(state="disabled", bg=self.btn_disabled_bg)
        
        self.update_step_ui()
        self.init_crop_frame()

    def update_step_ui(self):
        if self.step_idx < len(self.current_steps):
            label = self.current_steps[self.step_idx]
            self.btn_next.config(text=f"{label} 자르기 ▶")
            self.status_label.config(text=f"{label} 자를 부분을 선택해 주세요", fg=self.text_white)
            self.status_label.pack(pady=20, side="top", expand=False)

    def init_crop_frame(self):
        self.canvas.delete("all")
        self.canvas.create_image(self.safe_margin, self.safe_margin, anchor="nw", image=self.tk_display_img)
        w, h = self.display_img.width, self.display_img.height
        target_size = self.configs[self.game_select.get()]["sizes"][self.current_steps[self.step_idx]]
        r = target_size[0] / target_size[1]
        bw = w * 0.7
        bh = bw / r
        if bh > h * 0.9: 
            bh = h * 0.8
            bw = bh * r
        x1, y1 = ((w - bw) / 2) + self.safe_margin, ((h - bh) / 2) + self.safe_margin
        x2, y2 = x1 + bw, y1 + bh
        self.rect_id = self.canvas.create_rectangle(x1, y1, x2, y2, outline=self.accent_color, width=self.rect_width)

    def next_step(self):
        if self.step != "CROPPING": return
        self.crops[self.current_steps[self.step_idx]] = self.get_current_crop()
        self.step_idx += 1
        if self.step_idx < len(self.current_steps):
            self.update_step_ui()
            self.init_crop_frame()
        else:
            self.show_review()

    def get_current_crop(self):
        coords = self.canvas.coords(self.rect_id)
        #x1, y1, x2, y2 = self.canvas.coords(self.rect_id)
        x1, y1, x2, y2 = coords[0], coords[1], coords[2], coords[3]
        rx1 = (x1 - self.safe_margin) / self.scale_ratio
        ry1 = (y1 - self.safe_margin) / self.scale_ratio
        rx2 = (x2 - self.safe_margin) / self.scale_ratio
        ry2 = (y2 - self.safe_margin) / self.scale_ratio
        
        # [핵심 보정] 소수점 반올림 및 경계 스냅 (652/1024 오차 해결)
        rx1, ry1, rx2, ry2 = round(rx1), round(ry1), round(rx2), round(ry2)
        if rx1 < 10: rx1 = 0
        if ry1 < 10: ry1 = 0
        if abs(rx2 - self.original_img.width) < 10: rx2 = self.original_img.width
        if abs(ry2 - self.original_img.height) < 10: ry2 = self.original_img.height
        
        return self.original_img.crop((max(0, rx1), max(0, ry1), min(self.original_img.width, rx2), min(self.original_img.height, ry2)))

    def show_review(self):
        self.step = "REVIEW"
        self.canvas.place_forget()
        self.btn_next.pack_forget()
        
        for widget in self.review_frame.winfo_children():
            widget.destroy()
            
        self.review_frame.place(relx=0.5, rely=0.5, anchor="center")
        
        self.root.update_idletasks()
        panel_h = self.work_panel.winfo_height()
        fixed_h = int(panel_h * 0.60) if panel_h > 100 else 400
        
        game_cfg = self.configs[self.game_select.get()]
        for label, img in self.crops.items():
            container = tk.Frame(self.review_frame, bg=self.bg_dark)
            container.pack(side="left", padx=20, anchor="n")
            
            orig_w, orig_h = img.size
            target_w, target_h = game_cfg["sizes"][label]
            
            p_h = fixed_h
            p_w = int(p_h * (orig_w/orig_h))
            if p_h <= 0 or p_w <= 0: continue
            
            p_img = img.resize((p_w, p_h), Image.LANCZOS)
            tk_p = ImageTk.PhotoImage(p_img)
            
            lbl_img = tk.Label(container, image=tk_p, bg="#000", bd=1, relief="solid")
            lbl_img.image = tk_p
            lbl_img.pack()
            
            tk.Label(container, text=label, fg=self.accent_color, bg=self.bg_dark, font=self.bold_font).pack(pady=(10, 2))
            tk.Label(container, text=f"현재 크기: {int(orig_w)}x{int(orig_h)}", fg=self.text_white, bg=self.bg_dark, font=("Arial", 9)).pack()
            
            # 실제 게임 타겟 사이즈와 비교하여 저장 시 리사이즈 여부 표시
            if orig_w > target_w or orig_h > target_h:
                msg, color = f"* {target_w}x{target_h}로 축소됨", "#FF9800"
            else:
                msg, color = "* 원본 크기 유지", "#4CAF50"
                
            tk.Label(container, text=msg, fg=color, bg=self.bg_dark, font=("Arial", 9, "bold")).pack(pady=(2, 0))

        self.btn_save.config(state="normal", bg=self.accent_color, fg=self.bg_dark)
        self.btn_retry.config(state="normal", bg="#333a45", fg=self.text_white)
        self.status_label.config(text="최종 저장 전 해상도와 변경 사항을 확인하세요", fg=self.accent_color)

    def save_portraits(self):
        name = self.char_name_var.get().strip()
        selected_game = self.game_select.get()
        cfg = self.configs[selected_game]
        
        safe_game_name = re.sub(r'[\\/:*?"<>|]', '', selected_game)
        save_dir = os.path.join(self.base_dir, safe_game_name)
        
        try:
            if not os.path.exists(save_dir): 
                os.makedirs(save_dir)
            
            final_path = os.path.join(save_dir, name) if cfg.get("use_folder") else save_dir
            if not os.path.exists(final_path): 
                os.makedirs(final_path)

            for label, img in self.crops.items():
                orig_w, orig_h = img.size
                target_w, target_h = cfg["sizes"][label]
                
                # [수정] 픽셀 오차 해결을 위해 항상 타겟 사이즈로 최종 리사이징 (강제 정합)
                final_img = img.resize((target_w, target_h), Image.LANCZOS)
                
                fn = f"{label}.png" if cfg.get("use_folder") else f"{name}{cfg['suffix'][label]}.{cfg['format'].lower()}"
                save_full_path = os.path.join(final_path, fn)
                
                if cfg["format"] == "PNG":
                    final_img.save(save_full_path, "PNG")
                else:
                    if "Classics" in selected_game and label == "Small":
                        final_img.convert("P", palette=Image.ADAPTIVE, colors=256).save(save_full_path, "BMP")
                    else:
                        final_img.convert("RGB").save(save_full_path, "BMP")
                        
            messagebox.showinfo("완료", f"'{name}' 포트레이트가 저장되었습니다:\n{final_path}")
        except Exception as e: 
            messagebox.showerror("에러", str(e))

    def on_drag(self, event):
        if self.step != "CROPPING": return
        x1, y1, x2, y2 = self.canvas.coords(self.rect_id)
        min_x, min_y = self.safe_margin, self.safe_margin + self.frame_padding 
        max_x, max_y = self.display_img.width + self.safe_margin -2, self.display_img.height + self.safe_margin - self.frame_padding - 2
        
        if self.mode == 'move':
            dx, dy = event.x - self.start_x, event.y - self.start_y
            if x1 + dx < min_x: dx = min_x - x1
            if x2 + dx > max_x: dx = max_x - x2
            if y1 + dy < min_y: dy = min_y - y1
            if y2 + dy > max_y: dy = max_y - y2
            self.canvas.move(self.rect_id, dx, dy)
            self.start_x, self.start_y = event.x, event.y
            
        elif self.mode.startswith('resize'):
            target_size = self.configs[self.game_select.get()]["sizes"][self.current_steps[self.step_idx]]
            ratio = target_size[1] / target_size[0]
            
            # 리사이즈 시 경계 스냅 처리
            cx, cy = event.x, event.y
            if cx > max_x - 8: cx = max_x
            if cx < min_x + 8: cx = min_x
            
            cur_nx1, cur_ny1, cur_nx2, cur_ny2 = x1, y1, x2, y2
            
            if 'top' in self.mode:
                anchor_y = y2
                moving_y = max(min_y, min(cy, anchor_y - self.min_size))
                new_h = anchor_y - moving_y
                new_w = new_h / ratio
                moving_x = min(max_x, x1 + new_w)
                cur_ny1, cur_nx2 = moving_y, moving_x
                
            elif 'bottom' in self.mode:
                anchor_y = y1
                moving_y = min(max_y, max(cy, anchor_y + self.min_size))
                new_h = moving_y - anchor_y
                new_w = new_h / ratio
                moving_x = min(max_x, x1 + new_w)
                cur_ny2, cur_nx2 = moving_y, moving_x
                
            elif 'right' in self.mode:
                anchor_x = x1
                moving_x = min(max_x, max(cx, anchor_x + self.min_size))
                new_w = moving_x - anchor_x
                new_h = new_w * ratio
                moving_y = min(max_y, y1 + new_h)
                cur_nx2, cur_ny2 = moving_x, moving_y
                
            elif 'left' in self.mode:
                anchor_x = x2
                moving_x = max(min_x, min(cx, anchor_x - self.min_size))
                new_w = anchor_x - moving_x
                new_h = new_w * ratio
                moving_y = min(max_y, y1 + new_h)
                cur_nx1, cur_ny2 = moving_x, moving_y

            final_w = cur_nx2 - cur_nx1
            final_h = final_w * ratio
            
            if cur_nx1 + final_w > max_x:
                final_w = max_x - cur_nx1
                final_h = final_w * ratio
            if cur_ny1 + final_h > max_y:
                final_h = max_y - cur_ny1
                final_w = final_h / ratio
                
            if 'top' in self.mode:
                self.canvas.coords(self.rect_id, x1, y2 - final_h, x1 + final_w, y2)
            elif 'bottom' in self.mode:
                self.canvas.coords(self.rect_id, x1, y1, x1 + final_w, y1 + final_h)
            elif 'right' in self.mode:
                self.canvas.coords(self.rect_id, x1, y1, x1 + final_w, y1 + final_h)
            elif 'left' in self.mode:
                self.canvas.coords(self.rect_id, x2 - final_w, y1, x2, y1 + final_h)

    def on_click(self, event):
        if self.step != "CROPPING": return
        self.start_x, self.start_y = event.x, event.y
        try:
            x1, y1, x2, y2 = self.canvas.coords(self.rect_id)
            margin = 15
            self.mode = 'move'
            if abs(event.y - y1) < margin: self.mode = 'resize_top'
            elif abs(event.y - y2) < margin: self.mode = 'resize_bottom'
            elif abs(event.x - x1) < margin: self.mode = 'resize_left'
            elif abs(event.x - x2) < margin: self.mode = 'resize_right'
            else: self.mode = 'move'
        except: pass

    def update_cursor(self, event):
        if self.step != "CROPPING": return
        try:
            x1, y1, x2, y2 = self.canvas.coords(self.rect_id)
            margin = 15
            if abs(event.y - y1) < margin or abs(event.y - y2) < margin:
                self.canvas.config(cursor="sb_v_double_arrow")
            elif abs(event.x - x1) < margin or abs(event.x - x2) < margin:
                self.canvas.config(cursor="sb_h_double_arrow")
            else:
                self.canvas.config(cursor="fleur")
        except: pass

    def on_window_resize(self, event):
        if not self.original_img: return
        curr_w = self.root.winfo_width()
        curr_h = self.root.winfo_height()
        
        if abs(curr_w - self.last_width) > 5 or abs(curr_h - self.last_height) > 5:
            self.last_width, self.last_height = curr_w, curr_h
            if self.step == "CROPPING":
                self.refresh_display_size()
                self.init_crop_frame()
            elif self.step == "REVIEW":
                self.show_review()
            
    def limit_char_name(self, *args):
        value = self.char_name_var.get()
        v = re.sub(r'[^a-zA-Z0-9]', '', value)[:15]
        if value != v:
            self.char_name_var.set(v)

if __name__ == "__main__":
    root = TkinterDnD.Tk()
    app = PortraitMaker(root)
    root.mainloop()