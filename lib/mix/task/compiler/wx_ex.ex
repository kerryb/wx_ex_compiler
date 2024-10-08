defmodule Mix.Tasks.Compile.WxEx do
  @moduledoc """
  Compiler to produce Erlang and Elixir source files containing wrapper
  functions for all the wxWidgets and OpenGL static macros.

  Used internally by [wx_ex](https://hex.pm/packages/wx_ex).
  """
  use Mix.Task.Compiler

  @header_root ~C"wx" |> :code.lib_dir() |> to_string() |> Path.join("include")
  @generated_erl_root "src"
  @generated_ex_root Path.join(["lib", "generated", "wx_ex", "constants"])

  @wx_header_path Path.join(@header_root, "wx.hrl")
  @gl_header_path Path.join(@header_root, "gl.hrl")

  @wx_constants_erl_path Path.join(@generated_erl_root, "wx_constants.erl")
  @gl_constants_erl_path Path.join(@generated_erl_root, "gl_constants.erl")

  @wx_constants_ex_path Path.join(@generated_ex_root, "wx_widgets.ex")
  @gl_constants_ex_path Path.join(@generated_ex_root, "open_gl.ex")

  @generated_files [@gl_constants_erl_path, @wx_constants_erl_path, @gl_constants_ex_path, @wx_constants_ex_path]

  def run(_args) do
    @wx_constants_erl_path |> Path.dirname() |> File.mkdir_p!()
    wx_erl_file = File.open!(@wx_constants_erl_path, [:write])

    @wx_constants_ex_path |> Path.dirname() |> File.mkdir_p!()
    wx_ex_file = File.open!(@wx_constants_ex_path, [:write])

    @gl_constants_erl_path |> Path.dirname() |> File.mkdir_p!()
    gl_erl_file = File.open!(@gl_constants_erl_path, [:write])

    @gl_constants_ex_path |> Path.dirname() |> File.mkdir_p!()
    gl_ex_file = File.open!(@gl_constants_ex_path, [:write])

    write_wx_erl_preamble(wx_erl_file)
    write_gl_erl_preamble(gl_erl_file)

    write_wx_ex_preamble(wx_ex_file)
    write_gl_ex_preamble(gl_ex_file)

    @wx_header_path
    |> File.stream!()
    |> Stream.filter(&is_constant_macro?/1)
    |> Enum.each(fn line ->
      IO.write(wx_erl_file, generate_erl_function(line, :wx))
      IO.write(wx_ex_file, generate_ex_function(line, :wx))
    end)

    @gl_header_path
    |> File.stream!()
    |> Stream.filter(&is_constant_macro?/1)
    |> Enum.each(fn line ->
      IO.write(gl_erl_file, generate_erl_function(line, :gl))
      IO.write(gl_ex_file, generate_ex_function(line, :gl))
    end)

    IO.puts(wx_ex_file, "end")
    IO.puts(gl_ex_file, "end")

    File.close(wx_erl_file)
    File.close(gl_erl_file)
    File.close(wx_ex_file)
    File.close(gl_ex_file)

    :ok
  end

  defp write_wx_erl_preamble(file) do
    IO.write(file, ~S"""
    %% THIS FILE IS AUTOMATICALLY GENERATED
    %%
    %% @doc Function wrappers for the macros defined in wx.hrl. Note that all
    %% functions begin with lower case "wx": for example WXK_NONE is wrapped
    %% with the function wxK_NONE/0.

    -module(wx_constants).
    -compile(nowarn_export_all).
    -compile(export_all).
    -include_lib("wx/include/wx.hrl").
    """)
  end

  defp write_gl_erl_preamble(file) do
    IO.write(file, ~S"""
    %% THIS FILE IS AUTOMATICALLY GENERATED
    %%
    %% @doc Function wrappers for the macros defined in gl.hrl. Note that all
    %% functions begin with lower case "gl": for example GL_COLOR_BUFFER_BIT is wrapped
    %% with the function gl_COLOR_BUFFER_BIT/0.

    -module(gl_constants).
    -compile(nowarn_export_all).
    -compile(export_all).
    -include_lib("wx/include/gl.hrl").
    """)
  end

  defp write_wx_ex_preamble(file) do
    IO.write(file, ~S'''
    # THIS FILE IS AUTOMATICALLY GENERATED

    defmodule WxEx.Constants.WxWidgets do
      @moduledoc """
      Function wrappers for the macros defined in `wx.hrl`. Note that all
      functions begin with lower case "wx": for example `WXK_NONE` is wrapped
      with the function `wxK_NONE/0`.
      """

    ''')
  end

  defp write_gl_ex_preamble(file) do
    IO.write(file, ~S'''
    # THIS FILE IS AUTOMATICALLY GENERATED

    defmodule WxEx.Constants.OpenGL do
      @moduledoc """
      Function wrappers for the macros defined in `gl.hrl`. Note that all
      functions begin with lower case "gl": for example `GL_COLOR_BUFFER_BIT` is wrapped
      with the function `gl_COLOR_BUFFER_BIT/0`.
      """

    ''')
  end

  defp is_constant_macro?("-define(" <> _), do: true
  defp is_constant_macro?(_), do: false

  defp generate_erl_function(line, :wx) do
    String.replace(line, ~r/-define\((wx)(\w*).*/i, "wx\\2() -> ?\\1\\2.")
  end

  defp generate_erl_function(line, :gl) do
    String.replace(line, ~r/-define\((gl)(\w*).*/i, "gl\\2() -> ?\\1\\2.")
  end

  defp generate_ex_function(line, :wx) do
    line
    |> String.replace(~r/-define\((wx)(\w*).*/i, "  def wx\\2, do: :wx_constants.wx\\2()")
    |> wrap_long_lines()
  end

  defp generate_ex_function(line, :gl) do
    line
    |> String.replace(~r/-define\((gl)(\w*).*/i, "  def gl\\2, do: :gl_constants.gl\\2()")
    |> wrap_long_lines()
  end

  defp wrap_long_lines(line) do
    if String.length(line) > 122 do
      String.replace(line, ", do:", ",\n    do:")
    else
      line
    end
  end

  def clean do
    Enum.each(@generated_files, &File.rm_rf!/1)
  end
end
